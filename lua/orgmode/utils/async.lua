local Async = {}

local max_timeout = 120000
local copcall = package.loaded.jit and pcall or require('coxpcall').pcall

---@param value any
---@return boolean
local function is_task(value)
  return type(value) == 'table' and type(value.await) == 'function'
end

---@class OrgTask
---@field _subscribe fun(self: OrgTask, callback: fun(err: string?, ...: any))
---@field wait fun(self: OrgTask, timeout?: integer): any
---@field await fun(self: OrgTask, timeout?: integer): any

---@return OrgTask, fun(...: any), fun(err: any)
local function create_task()
  local res ---@type { n: integer, [integer]: any }?
  local listeners = {}

  ---@param callback fun(err: string?, ...: any)
  local function subscribe(callback)
    if res ~= nil then
      callback(unpack(res, 1, res.n))
      return
    end
    table.insert(listeners, callback)
  end

  local function finish(err, ...)
    if res ~= nil then
      return
    end

    res = vim.F.pack_len(err, ...)
    for _, listener in ipairs(listeners) do
      listener(err, ...)
    end
  end

  local task = {
    _subscribe = function(_, callback)
      subscribe(callback)
    end,
    wait = function(_, timeout)
      vim.wait(timeout or max_timeout, function()
        return res ~= nil
      end)

      assert(res, 'timeout')
      if res[1] then
        error(res[1])
      end

      return unpack(res, 2, res.n)
    end,
    await = function(self, timeout)
      if not coroutine.running() then
        return self:wait(timeout)
      end

      local result = vim.F.pack_len(Async.await(1, function(callback)
        self:_subscribe(function(err, ...)
          callback(err, ...)
        end)
      end))

      if result[1] then
        error(result[1])
      end

      return unpack(result, 2, result.n)
    end,
  }

  return task, function(...)
    finish(nil, ...)
  end, function(err)
    finish(err)
  end
end

---@param thread thread
---@param on_finish fun(err: string?, ...: any)
---@param ... any
local function resume(thread, on_finish, ...)
  local ret = vim.F.pack_len(coroutine.resume(thread, ...))
  local stat = ret[1]

  if not stat then
    on_finish(ret[2])
  elseif coroutine.status(thread) == 'dead' then
    on_finish(nil, unpack(ret, 2, ret.n))
  else
    local fn = ret[2]

    local ok, err = copcall(fn, function(...)
      resume(thread, on_finish, ...)
    end)

    if not ok then
      on_finish(err)
    end
  end
end

---@return boolean
function Async.running()
  return coroutine.running() ~= nil
end

---@param ... any
---@return OrgTask
function Async.done(...)
  local args = vim.F.pack_len(...)
  return Async.task(function(resolve)
    resolve(unpack(args, 1, args.n))
  end)
end

---@param err any
---@return OrgTask
function Async.failed(err)
  return Async.task(function(_, reject)
    reject(err)
  end)
end

---@param executor fun(resolve: fun(...: any), reject: fun(err: any))
---@return OrgTask
function Async.task(executor)
  local task, resolve, reject = create_task()
  local ok, err = pcall(executor, resolve, reject)
  if not ok then
    reject(err)
  end
  return task
end

---@param func async fun(): ...: any
---@param on_finish? fun(err: string?, ...: any)
---@return OrgTask
function Async.run(func, on_finish)
  local task, resolve, reject = create_task()

  if on_finish then
    task:_subscribe(on_finish)
  end

  resume(coroutine.create(func), function(err, ...)
    if err then
      reject(err)
      return
    end
    local results = vim.F.pack_len(...)
    if results.n == 1 and is_task(results[1]) then
      results[1]:_subscribe(function(task_err, ...)
        if task_err then
          reject(task_err)
          return
        end
        resolve(...)
      end)
      return
    end
    resolve(unpack(results, 1, results.n))
  end)

  return task
end

--- Asynchronous blocking wait
---@async
---@param argc integer
---@param fun function
---@param ... any
---@return any ...
function Async.await(argc, fun, ...)
  assert(coroutine.running(), 'Async.await() must be called from an async function')
  local args = vim.F.pack_len(...)

  return coroutine.yield(function(callback)
    args[argc] = assert(callback)
    fun(unpack(args, 1, math.max(argc, args.n)))
  end)
end

---@param value any
---@param timeout? integer
---@return any ...
function Async.awaitable(value, timeout)
  if is_task(value) then
    return value:await(timeout)
  end

  return value
end

---@param callback fun(value: any, index: integer, list: any[]): any
---@param list any[]
---@param concurrency? integer
---@return OrgTask
function Async.map(callback, list, concurrency)
  vim.validate('list', list, 'table')
  vim.validate('callback', callback, 'function')
  vim.validate('concurrency', concurrency, 'number', true)

  local results = {}
  local processing = 0
  local index = 1
  local settled = false
  concurrency = concurrency or #list

  return Async.task(function(resolve, reject)
    if #list == 0 then
      resolve(results)
      return
    end

    local function process_next()
      if settled then
        return
      end

      if index > #list then
        if processing == 0 then
          settled = true
          resolve(results)
        end
        return
      end

      local i = index
      index = index + 1
      processing = processing + 1

      Async.run(function()
        return callback(list[i], i, list)
      end, function(err, ...)
        processing = processing - 1
        if settled then
          return
        end

        if err then
          settled = true
          reject(err)
          return
        end

        results[i] = ...
        process_next()

        if index > #list and processing == 0 and not settled then
          settled = true
          resolve(results)
        end
      end)
    end

    for _ = 1, math.min(concurrency, #list) do
      process_next()
    end
  end)
end

---@param callback fun(value: any, index: integer, list: any[]): any
---@param list any[]
---@return OrgTask
function Async.map_series(callback, list)
  return Async.map(callback, list, 1)
end

---@param list any[]
---@return OrgTask
function Async.all(list)
  return Async.map(function(value)
    return value
  end, list)
end

---@async
---@param max_jobs integer
---@param funs (async fun())[]
function Async.join(max_jobs, funs)
  if #funs == 0 then
    return
  end

  max_jobs = math.min(max_jobs, #funs)

  local remaining = { select(max_jobs + 1, unpack(funs)) }
  local to_go = #funs

  Async.await(1, function(on_finish)
    local function run_next()
      to_go = to_go - 1
      if to_go == 0 then
        on_finish()
      elseif #remaining > 0 then
        local next_fun = table.remove(remaining)
        Async.run(next_fun, run_next)
      end
    end

    for i = 1, max_jobs do
      Async.run(funs[i], run_next)
    end
  end)
end

return Async

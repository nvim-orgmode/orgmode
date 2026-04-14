local Promise = require('orgmode.utils.promise')

local Async = {}

local max_timeout = 120000
local copcall = package.loaded.jit and pcall or require('coxpcall').pcall

--- @param thread thread
--- @param on_finish fun(err: string?, ...:any)
--- @param ... any
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

--- @return boolean
function Async.running()
  return coroutine.running() ~= nil
end

--- @param func async fun(): ...:any
--- @param on_finish? fun(err: string?, ...:any)
function Async.run(func, on_finish)
  local res --- @type {n: integer, [integer]: any}?
  local listeners = {}

  local function finish(err, ...)
    res = vim.F.pack_len(err, ...)
    if on_finish then
      on_finish(err, ...)
    end
    for _, listener in ipairs(listeners) do
      listener(err, ...)
    end
  end

  resume(coroutine.create(func), finish)

  return {
    _subscribe = function(_self, callback)
      if res ~= nil then
        callback(unpack(res, 1, res.n))
        return
      end
      table.insert(listeners, callback)
    end,
    --- @param timeout? integer
    --- @return any ...
    wait = function(_self, timeout)
      vim.wait(timeout or max_timeout, function()
        return res ~= nil
      end)
      assert(res, 'timeout')
      if res[1] then
        error(res[1])
      end
      return unpack(res, 2, res.n)
    end,
    --- @param timeout? integer
    --- @return any ...
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
end

--- Asynchronous blocking wait
--- @async
--- @param argc integer
--- @param fun function
--- @param ... any
--- @return any ...
function Async.await(argc, fun, ...)
  assert(coroutine.running(), 'Async.await() must be called from an async function')
  local args = vim.F.pack_len(...)

  return coroutine.yield(function(callback)
    args[argc] = assert(callback)
    fun(unpack(args, 1, math.max(argc, args.n)))
  end)
end

--- @param promise OrgPromise | any
--- @param timeout? integer
--- @return any ...
function Async.await_promise(promise, timeout)
  if getmetatable(promise) ~= Promise then
    return promise
  end

  if not coroutine.running() then
    return promise:wait(timeout)
  end

  local result = vim.F.pack_len(Async.await(1, function(callback)
    promise
      :next(function(...)
        callback(nil, ...)
      end)
      :catch(function(err)
        callback(err)
      end)
  end))

  if result[1] then
    error(result[1])
  end

  return unpack(result, 2, result.n)
end

--- @param value any
--- @param timeout? integer
--- @return any ...
function Async.awaitable(value, timeout)
  if getmetatable(value) == Promise then
    return Async.await_promise(value, timeout)
  end

  if type(value) == 'table' and type(value.await) == 'function' then
    return value:await(timeout)
  end

  return value
end

--- @async
--- @param max_jobs integer
--- @param funs (async fun())[]
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

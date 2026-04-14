local unpack = unpack or table.unpack
local F = vim.F

---@alias OrgPromiseState '"pending"'|'"fulfilled"'|'"rejected"'

---@class OrgPromisePackedValues
---@field n integer
---@field [integer] any

---@class OrgPromise<T>
---@field _state OrgPromiseState
---@field _value OrgPromisePackedValues|nil
---@field _handled boolean
---@field _unhandled_check_scheduled boolean
---@field _subscribers fun()[]
local Promise = {}
Promise.__index = Promise

---@type OrgPromiseState
local PENDING = 'pending'
---@type OrgPromiseState
local FULFILLED = 'fulfilled'
---@type OrgPromiseState
local REJECTED = 'rejected'
local AWAIT = {}
local managed_threads = setmetatable({}, { __mode = 'k' })

---@param value any
---@return boolean
local function is_promise(value)
  return type(value) == 'table' and getmetatable(value) == Promise
end

---@return OrgPromisePackedValues
local function pack_values(...)
  return F.pack_len(...)
end

---@param values OrgPromisePackedValues
---@param from? integer
local function unpack_values(values, from)
  if (from or 1) == 1 then
    return F.unpack_len(values)
  end
  return unpack(values, from, values.n)
end

---@param values OrgPromisePackedValues
---@return any
local function first_value(values)
  return values[1]
end

---@param fn fun(...: any)
---@param ... any
local function schedule(fn, ...)
  local args = pack_values(...)

  vim.schedule(function()
    fn(unpack_values(args))
  end)
end

---@generic T
---@param fn fun(...: any): T|OrgPromise<T>
---@param on_success fun(...: any)
---@param on_error fun(...: any)
---@param ... any
local function run_coroutine(fn, on_success, on_error, ...)
  local thread = coroutine.create(fn)
  managed_threads[thread] = true

  local function step(...)
    local result = pack_values(coroutine.resume(thread, ...))
    if not result[1] then
      managed_threads[thread] = nil
      on_error(unpack_values(result, 2))
      return
    end

    if coroutine.status(thread) == 'dead' then
      managed_threads[thread] = nil
      on_success(unpack_values(result, 2))
      return
    end

    if result[2] == AWAIT then
      local promise = result[3]
      Promise.resolve(promise):next(function(...)
        step(true, pack_values(...))
      end, function(...)
        step(false, pack_values(...))
      end)
      return
    end

    Promise.resolve(unpack_values(result, 2)):next(step, on_error)
  end

  step(...)
end

---@generic T
---@param promise OrgPromise<T>
local function flush(promise)
  if promise._state == PENDING then
    return
  end

  local subscribers = promise._subscribers
  promise._subscribers = {}

  for _, subscriber in ipairs(subscribers) do
    subscriber()
  end
end

---@generic T
---@param promise OrgPromise<T>
local function schedule_unhandled_check(promise)
  if promise._unhandled_check_scheduled then
    return
  end

  promise._unhandled_check_scheduled = true

  vim.schedule(function()
    promise._unhandled_check_scheduled = false

    if promise._state ~= REJECTED or promise._handled then
      return
    end

    local reason = first_value(promise._value)
    if reason == 'Keyboard interrupt' then
      return
    end

    error('unhandled promise rejection: ' .. vim.inspect({ reason }, { newline = '', indent = '' }), 0)
  end)
end

---@generic T
---@param promise OrgPromise<T>
---@param ... any
local function reject_promise(promise, ...)
  if promise._state ~= PENDING then
    return
  end

  promise._state = REJECTED
  promise._value = pack_values(...)
  promise._handled = promise._handled or #promise._subscribers > 0
  schedule_unhandled_check(promise)
  flush(promise)
end

---@generic T
---@param promise OrgPromise<T>
---@param ... T
local function fulfill_promise(promise, ...)
  if promise._state ~= PENDING then
    return
  end

  promise._state = FULFILLED
  promise._value = pack_values(...)
  flush(promise)
end

---@generic T
---@param promise OrgPromise<T>
---@param ... T|OrgPromise<T>
local function resolve_promise(promise, ...)
  local argc = select('#', ...)
  local first = ...

  if argc == 1 and promise == first then
    reject_promise(promise, 'Cannot resolve a promise with itself')
    return
  end

  if argc == 1 and is_promise(first) then
    first:next(function(...)
      fulfill_promise(promise, ...)
    end, function(...)
      reject_promise(promise, ...)
    end)
    return
  end

  fulfill_promise(promise, ...)
end

---@generic T
---@param executor fun(resolve: fun(...: T|OrgPromise<T>), reject: fun(...: any))
---@return OrgPromise<T>
function Promise.new(executor)
  assert(type(executor) == 'function', 'Promise.new expects an executor function')

  ---@type OrgPromise<T>
  local promise = setmetatable({
    _state = PENDING,
    _value = nil,
    _handled = false,
    _unhandled_check_scheduled = false,
    _subscribers = {},
  }, Promise)

  local settled = false

  local function resolve(...)
    if settled then
      return
    end

    settled = true
    resolve_promise(promise, ...)
  end

  local function reject(...)
    if settled then
      return
    end

    settled = true
    reject_promise(promise, ...)
  end

  run_coroutine(function()
    executor(resolve, reject)
  end, function() end, reject)

  return promise
end

---@generic T
---@param ... T|OrgPromise<T>
---@return OrgPromise<T>
function Promise.resolve(...)
  local argc = select('#', ...)
  local first = ...

  if argc == 1 and is_promise(first) then
    return first
  end

  ---@type OrgPromise<T>
  local promise = setmetatable({
    _state = PENDING,
    _value = nil,
    _handled = false,
    _unhandled_check_scheduled = false,
    _subscribers = {},
  }, Promise)

  resolve_promise(promise, ...)

  return promise
end

---@param ... any
---@return OrgPromise<any>
function Promise.reject(...)
  local argc = select('#', ...)
  local first = ...

  if argc == 1 and is_promise(first) then
    return first
  end

  ---@type OrgPromise<any>
  local promise = setmetatable({
    _state = PENDING,
    _value = nil,
    _handled = false,
    _unhandled_check_scheduled = false,
    _subscribers = {},
  }, Promise)

  reject_promise(promise, ...)

  return promise
end

---@generic T, U
---@param self OrgPromise<T>
---@param on_fulfilled? fun(...: any): U|OrgPromise<U>
---@param on_rejected? fun(...: any): U|OrgPromise<U>
---@return OrgPromise<T|U>
function Promise:next(on_fulfilled, on_rejected)
  ---@type OrgPromise<T|U>
  local child = setmetatable({
    _state = PENDING,
    _value = nil,
    _handled = false,
    _unhandled_check_scheduled = false,
    _subscribers = {},
  }, Promise)

  local function run_callback()
    local callback = nil
    if self._state == FULFILLED then
      callback = on_fulfilled
    else
      callback = on_rejected
    end

    if callback == nil then
      if self._state == FULFILLED then
        fulfill_promise(child, unpack_values(self._value))
      else
        reject_promise(child, unpack_values(self._value))
      end
      return
    end

    run_coroutine(function()
      return callback(unpack_values(self._value))
    end, function(...)
      resolve_promise(child, ...)
    end, function(...)
      reject_promise(child, ...)
    end)
  end

  self._handled = true
  table.insert(self._subscribers, run_callback)

  if self._state ~= PENDING then
    schedule(run_callback)
  end

  return child
end

---@generic T, U
---@param self OrgPromise<T>
---@param on_rejected fun(reason: any): U|OrgPromise<U>
---@return OrgPromise<T|U>
function Promise:catch(on_rejected)
  return self:next(nil, on_rejected)
end

---@generic T
---@param self OrgPromise<T>
---@param on_finally fun()
---@return OrgPromise<T>
function Promise:finally(on_finally)
  assert(type(on_finally) == 'function', 'Promise.finally expects a callback function')

  return self:next(function(...)
    on_finally()
    return ...
  end, function(...)
    on_finally()
    return Promise.reject(...)
  end)
end

---@generic T
---@param self OrgPromise<T>
---@param timeout? integer
---@param interval? integer
---@return T
function Promise:wait(timeout, interval)
  self._handled = true

  if self._state == PENDING then
    local timeout_ms = timeout or 30000
    local ok = vim.wait(timeout_ms, function()
      return self._state ~= PENDING
    end, interval or 10)

    if not ok then
      error(('Promise timed out after %dms'):format(timeout_ms), 0)
    end
  end

  if self._state == REJECTED then
    error(first_value(self._value), 0)
  end

  return unpack_values(self._value)
end

---Run a function in a managed async coroutine context.
---@generic T
---@param callback fun(...: any): T|OrgPromise<T>
---@param ... any
---@return OrgPromise<T>
function Promise.async(callback, ...)
  assert(type(callback) == 'function', 'Promise.async expects a callback function')
  local args = pack_values(...)

  return Promise.new(function(resolve, reject)
    run_coroutine(callback, resolve, reject, unpack_values(args))
  end)
end

---Await promise resolution without blocking the event loop.
---Must be called from a yieldable managed async coroutine context.
---@generic T
---@return T
function Promise:await()
  local thread, is_main = coroutine.running()
  if not thread or is_main  then
    error('promise:await() must be called from a yieldable async context', 0)
  end

  if self._state == FULFILLED then
    return unpack_values(self._value)
  end

  if self._state == REJECTED then
    error(first_value(self._value), 0)
  end

  if not managed_threads[thread] then
    self:next(function(...)
      coroutine.resume(thread, true, pack_values(...))
    end, function(...)
      coroutine.resume(thread, false, pack_values(...))
    end)

    local ok, values = coroutine.yield()
    if not ok then
      error(first_value(values), 0)
    end

    return unpack_values(values)
  end

  local ok, values = coroutine.yield(AWAIT, self)
  if not ok then
    error(first_value(values), 0)
  end

  return unpack_values(values)
end

---@generic T
---@param items (T|OrgPromise<T>)[]
---@return OrgPromise<T[]>
function Promise.all(items)
  assert(type(items) == 'table', 'Promise.all expects a list-like table')

  local total = #items

  if total == 0 then
    return Promise.resolve({})
  end

  return Promise.new(function(resolve, reject)
    ---@type T[]
    local results = {}
    local completed = 0
    local settled = false

    for index, item in ipairs(items) do
      Promise.resolve(item):next(function(value)
        if settled then
          return
        end

        results[index] = value
        completed = completed + 1

        if completed == total then
          settled = true
          resolve(results)
        end
      end, function(reason)
        if settled then
          return
        end

        settled = true
        reject(reason)
      end)
    end
  end)
end

---@generic T, U
---@param mapper fun(item: T, index: integer, items: T[]): U|OrgPromise<U>
---@param items T[]
---@param concurrency? integer
---@return OrgPromise<U[]>
function Promise.map(mapper, items, concurrency)
  assert(type(items) == 'table', 'Promise.map expects a list-like table')
  assert(type(mapper) == 'function', 'Promise.map expects a mapper function')

  local total = #items
  concurrency = concurrency or total

  if total == 0 then
    return Promise.resolve({})
  end

  assert(type(concurrency) == 'number' and concurrency >= 1, 'Promise.map concurrency must be >= 1')
  concurrency = math.floor(concurrency)
  concurrency = math.min(concurrency, total)

  return Promise.new(function(resolve, reject)
    ---@type U[]
    local results = {}
    local next_index = 1
    local active = 0
    local completed = 0
    local settled = false

    local function pump()
      if settled then
        return
      end

      while active < concurrency and next_index <= total do
        local index = next_index
        next_index = next_index + 1
        active = active + 1

        run_coroutine(function()
          return mapper(items[index], index, items)
        end, function(value)
          Promise.resolve(value):next(function(resolved)
            if settled then
              return
            end

            results[index] = resolved
            active = active - 1
            completed = completed + 1

            if completed == total then
              settled = true
              resolve(results)
              return
            end

            pump()
          end, function(reason)
            if settled then
              return
            end

            settled = true
            active = active - 1
            reject(reason)
          end)
        end, function(reason)
          if settled then
            return
          end

          settled = true
          active = active - 1
          reject(reason)
        end)
      end
    end

    pump()
  end)
end

---@generic T, U
---@param mapper fun(item: T, index: integer, items: T[]): U|OrgPromise<U>
---@param items T[]
---@return OrgPromise<U[]>
function Promise.mapSeries(mapper, items)
  return Promise.map(mapper, items, 1)
end

return Promise

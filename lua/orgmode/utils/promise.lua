---@diagnostic disable: undefined-field
-- Taken from https://github.com/notomo/promise.nvim

local vim = vim

local PackedValue = {}
PackedValue.__index = PackedValue

function PackedValue.new(...)
  local values = vim.F.pack_len(...)
  local tbl = { _values = values }
  return setmetatable(tbl, PackedValue)
end

function PackedValue.pcall(self, f)
  local ok_and_value = function(ok, ...)
    return ok, PackedValue.new(...)
  end
  return ok_and_value(pcall(f, self:unpack()))
end

function PackedValue.unpack(self)
  return vim.F.unpack_len(self._values)
end

function PackedValue.first(self)
  local first = self:unpack()
  return first
end

--- @generic T : any
--- @generic V : any
--- @class OrgPromise<T, V>: { next: fun(self: OrgPromise<T>, resolve:fun(result:T):V), wait: fun(self: OrgPromise<T>, timeout?: number):V }
local Promise = {}
Promise.__index = Promise

local PromiseStatus = { Pending = 'pending', Fulfilled = 'fulfilled', Rejected = 'rejected' }

local is_promise = function(v)
  return getmetatable(v) == Promise
end

local new_empty_userdata = function()
  return newproxy(true)
end

local new_pending = function(on_fullfilled, on_rejected)
  vim.validate({
    on_fullfilled = { on_fullfilled, 'function', true },
    on_rejected = { on_rejected, 'function', true },
  })
  local tbl = {
    _status = PromiseStatus.Pending,
    _queued = {},
    _value = nil,
    _on_fullfilled = on_fullfilled,
    _on_rejected = on_rejected,
    _handled = false,
  }
  local self = setmetatable(tbl, Promise)

  local userdata = new_empty_userdata()
  self._unhandled_detector = setmetatable({ [self] = userdata }, { __mode = 'k' })
  getmetatable(userdata).__gc = function()
    if self._status ~= PromiseStatus.Rejected or self._handled then
      return
    end
    self._handled = true
    vim.schedule(function()
      local values = vim.inspect({ self._value:unpack() }, { newline = '', indent = '' })
      error('unhandled promise rejection: ' .. values, 0)
    end)
  end

  return self
end

--- Equivalents to JavaScript's Promise.new.
--- @param executor fun(resolve:fun(...:any),reject:fun(...:any))
--- @return OrgPromise
function Promise.new(executor)
  vim.validate({ executor = { executor, 'function' } })

  local self = new_pending()

  local resolve = function(...)
    local first = ...
    if is_promise(first) then
      first
        :next(function(...)
          self:_resolve(...)
        end)
        :catch(function(...)
          self:_reject(...)
        end)
      return
    end
    self:_resolve(...)
  end
  local reject = function(...)
    self:_reject(...)
  end
  executor(resolve, reject)

  return self
end

--- Returns a fulfilled promise.
--- But if the first argument is promise, returns the promise.
--- @param ... any: one promise or non-promises
--- @return OrgPromise
function Promise.resolve(...)
  local first = ...
  if is_promise(first) then
    return first
  end
  local value = PackedValue.new(...)
  return Promise.new(function(resolve, _)
    resolve(value:unpack())
  end)
end

--- Returns a rejected promise.
--- But if the first argument is promise, returns the promise.
--- @param ... any: one promise or non-promises
--- @return OrgPromise
function Promise.reject(...)
  local first = ...
  if is_promise(first) then
    return first
  end
  local value = PackedValue.new(...)
  return Promise.new(function(_, reject)
    reject(value:unpack())
  end)
end

function Promise._resolve(self, ...)
  if self._status == PromiseStatus.Rejected then
    return
  end
  self._status = PromiseStatus.Fulfilled
  self._value = PackedValue.new(...)
  for _ = 1, #self._queued do
    local promise = table.remove(self._queued, 1)
    promise:_start_resolve(self._value)
  end
end

function Promise._start_resolve(self, value)
  if not self._on_fullfilled then
    return vim.schedule(function()
      self:_resolve(value:unpack())
    end)
  end
  local ok, result = value:pcall(self._on_fullfilled)
  if not ok then
    return vim.schedule(function()
      self:_reject(result:unpack())
    end)
  end
  local first = result:first()
  if not is_promise(first) then
    return vim.schedule(function()
      self:_resolve(result:unpack())
    end)
  end
  first
    :next(function(...)
      self:_resolve(...)
    end)
    :catch(function(...)
      self:_reject(...)
    end)
end

function Promise._reject(self, ...)
  if self._status == PromiseStatus.Fulfilled then
    return
  end
  self._status = PromiseStatus.Rejected
  self._value = PackedValue.new(...)
  self._handled = self._handled or #self._queued > 0
  for _ = 1, #self._queued do
    local promise = table.remove(self._queued, 1)
    promise:_start_reject(self._value)
  end
end

function Promise._start_reject(self, value)
  if not self._on_rejected then
    return vim.schedule(function()
      self:_reject(value:unpack())
    end)
  end
  local ok, result = value:pcall(self._on_rejected)
  local first = result:first()
  if ok and not is_promise(first) then
    return vim.schedule(function()
      self:_resolve(result:unpack())
    end)
  end
  if not is_promise(first) then
    return vim.schedule(function()
      self:_reject(result:unpack())
    end)
  end
  first
    :next(function(...)
      self:_resolve(...)
    end)
    :catch(function(...)
      self:_reject(...)
    end)
end

--- Equivalents to JavaScript's Promise.then.
--- @param on_fullfilled (fun(...:any):any)?: A callback on fullfilled.
--- @param on_rejected (fun(...:any):any)?: A callback on rejected.
--- @return OrgPromise
function Promise.next(self, on_fullfilled, on_rejected)
  vim.validate({
    on_fullfilled = { on_fullfilled, 'function', true },
    on_rejected = { on_rejected, 'function', true },
  })
  local promise = new_pending(on_fullfilled, on_rejected)
  table.insert(self._queued, promise)
  vim.schedule(function()
    if self._status == PromiseStatus.Fulfilled then
      return self:_resolve(self._value:unpack())
    end
    if self._status == PromiseStatus.Rejected then
      return self:_reject(self._value:unpack())
    end
  end)
  return promise
end

--- Equivalents to JavaScript's Promise.catch.
--- @param on_rejected (fun(...:any):any)?: A callback on rejected.
--- @return OrgPromise
function Promise.catch(self, on_rejected)
  return self:next(nil, on_rejected)
end

--- Equivalents to JavaScript's Promise.finally.
--- @param on_finally fun()
--- @return OrgPromise
function Promise.finally(self, on_finally)
  vim.validate({ on_finally = { on_finally, 'function', true } })
  return self
    :next(function(...)
      on_finally()
      return ...
    end)
    :catch(function(...)
      on_finally()
      return Promise.reject(...)
    end)
end

--- Equivalents to JavaScript's Promise.then.
--- @param timeout? number
--- @return any
function Promise.wait(self, timeout)
  local is_done = false
  local has_error = false
  local result = nil

  self
    :next(function(...)
      result = PackedValue.new(...)
      is_done = true
    end)
    :catch(function(...)
      has_error = true
      result = PackedValue.new(...)
      is_done = true
    end)

  vim.wait(timeout or 5000, function()
    return is_done
  end, 1)

  local value = result and result:unpack()

  if has_error then
    return error(value)
  end

  return value
end

--- Equivalents to JavaScript's Promise.all.
--- Even if multiple value are resolved, results include only the first value.
--- @param list any[]: promise or non-promise values
--- @return OrgPromise
function Promise.all(list)
  vim.validate({ list = { list, 'table' } })
  return Promise.new(function(resolve, reject)
    local remain = #list
    if remain == 0 then
      return resolve({})
    end

    local results = {}
    for i, e in ipairs(list) do
      Promise.resolve(e)
        :next(function(...)
          local first = ...
          results[i] = first
          if remain == 1 then
            return resolve(results)
          end
          remain = remain - 1
        end)
        :catch(function(...)
          reject(...)
        end)
    end
  end)
end

--- Equivalents to JavaScript's Promise.race.
--- @param list any[]: promise or non-promise values
--- @return OrgPromise
function Promise.race(list)
  vim.validate({ list = { list, 'table' } })
  return Promise.new(function(resolve, reject)
    for _, e in ipairs(list) do
      Promise.resolve(e)
        :next(function(...)
          resolve(...)
        end)
        :catch(function(...)
          reject(...)
        end)
    end
  end)
end

--- Equivalents to JavaScript's Promise.any.
--- Even if multiple value are rejected, errors include only the first value.
--- @param list any[]: promise or non-promise values
--- @return OrgPromise
function Promise.any(list)
  vim.validate({ list = { list, 'table' } })
  return Promise.new(function(resolve, reject)
    local remain = #list
    if remain == 0 then
      return reject({})
    end

    local errs = {}
    for i, e in ipairs(list) do
      Promise.resolve(e)
        :next(function(...)
          resolve(...)
        end)
        :catch(function(...)
          local first = ...
          errs[i] = first
          if remain == 1 then
            return reject(errs)
          end
          remain = remain - 1
        end)
    end
  end)
end

--- Equivalents to JavaScript's Promise.allSettled.
--- Even if multiple value are resolved/rejected, value/reason is only the first value.
--- @param list any[]: promise or non-promise values
--- @return OrgPromise
function Promise.all_settled(list)
  vim.validate({ list = { list, 'table' } })
  return Promise.new(function(resolve)
    local remain = #list
    if remain == 0 then
      return resolve({})
    end

    local results = {}
    for i, e in ipairs(list) do
      Promise.resolve(e)
        :next(function(...)
          local first = ...
          results[i] = { status = PromiseStatus.Fulfilled, value = first }
        end)
        :catch(function(...)
          local first = ...
          results[i] = { status = PromiseStatus.Rejected, reason = first }
        end)
        :finally(function()
          if remain == 1 then
            return resolve(results)
          end
          remain = remain - 1
        end)
    end
  end)
end

return Promise

-- Taken from https://github.com/notomo/promise.nvim

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

local vim = vim

---@class Promise
local Promise = {}
Promise.__index = Promise

local PromiseStatus = { Pending = 'Pending', Fulfilled = 'Fulfilled', Rejected = 'Rejected' }

local is_promise = function(v)
  return getmetatable(v) == Promise
end

local new_any_userdata = function()
  local userdata = vim.loop.new_async(function() end)
  userdata:close()
  return userdata
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
    _unhandled_detector = new_any_userdata(),
  }
  local self = setmetatable(tbl, Promise)

  getmetatable(tbl._unhandled_detector).__gc = function()
    if self._status ~= PromiseStatus.Rejected or self._handled then
      return
    end
    self._handled = true
    vim.schedule(function()
      error('unhandled promise rejection: ' .. vim.inspect({ self._value:unpack() }))
    end)
  end

  return self
end

--- TODO doc
--- @param f function:
function Promise.new(f)
  vim.validate({ f = { f, 'function' } })

  local self = new_pending()

  local resolve = function(...)
    self:_resolve(...)
  end
  local reject = function(...)
    self:_reject(...)
  end
  f(resolve, reject)

  return self
end

--- TODO doc
--- @vararg any:
function Promise.resolve(...)
  local v = ...
  if is_promise(v) then
    return v
  end
  local value = PackedValue.new(...)
  return Promise.new(function(resolve, _)
    resolve(value:unpack())
  end)
end

--- TODO doc
--- @vararg any:
function Promise.reject(...)
  local v = ...
  if is_promise(v) then
    return v
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
  if self._status == PromiseStatus.Resolved then
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

--- TODO doc
--- @param on_fullfilled function|nil:
--- @param on_rejected function|nil:
function Promise.next(self, on_fullfilled, on_rejected)
  vim.validate({
    on_fullfilled = { on_fullfilled, 'function', true },
    on_rejected = { on_rejected, 'function', true },
  })
  local promise = new_pending(on_fullfilled, on_rejected)
  vim.schedule(function()
    if self._status == PromiseStatus.Fulfilled then
      return self:_resolve(self._value:unpack())
    end
    if self._status == PromiseStatus.Rejected then
      return self:_reject(self._value:unpack())
    end
  end)
  table.insert(self._queued, promise)
  return promise
end

--- TODO doc
--- @param on_rejected function|nil:
function Promise.catch(self, on_rejected)
  return self:next(nil, on_rejected)
end

--- TODO doc
--- @param on_finally function:
function Promise.finally(self, on_finally)
  vim.validate({ on_finally = { on_finally, 'function', true } })
  return self
    :next(function(...)
      on_finally()
      return ...
    end)
    :catch(function(...)
      on_finally()
      local value = PackedValue.new(...)
      return Promise.new(function(_, reject)
        reject(value:unpack())
      end)
    end)
end

--- TODO doc
--- @param list table:
function Promise.all(list)
  vim.validate({ list = { list, 'table' } })
  local remain = #list
  local results = {}
  return Promise.new(function(resolve, reject)
    if remain == 0 then
      return resolve(results)
    end

    for i, e in ipairs(list) do
      Promise.resolve(e)
        :next(function(...)
          -- use only the first argument
          results[i] = ...
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

--- TODO doc
--- @param list table:
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

return Promise

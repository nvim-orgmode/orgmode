local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')

---@class OrgState
local OrgState = { data = {}, _ctx = { loaded = false, saved = false, curr_loader = nil, savers = 0, dirty = false } }

local cache_path = vim.fs.normalize(vim.fn.stdpath('cache') .. '/org-cache.json', { expand_env = false })

---Returns the current OrgState singleton
---@return OrgState
function OrgState.new()
  -- This is done so we can later iterate the 'data'
  -- subtable cleanly and shove it into a cache
  setmetatable(OrgState, {
    __index = function(tbl, key)
      return tbl.data[key]
    end,
    __newindex = function(tbl, key, value)
      if tbl.data[key] ~= value then
        tbl._ctx.dirty = true
      end
      tbl.data[key] = value
    end,
  })
  local self = OrgState
  -- Start trying to load the state from cache as part of initializing the state
  self:load()
  return self
end

---Save the current state to cache
---@return OrgPromise
function OrgState:save()
  if not OrgState._ctx.dirty then
    return Promise.resolve(self)
  end
  OrgState._ctx.saved = false
  --- We want to ensure the state was loaded before saving.
  self:load()
  self._ctx.savers = self._ctx.savers + 1
  return utils
    .writefile(cache_path, vim.json.encode(OrgState.data))
    :next(function()
      self._ctx.savers = self._ctx.savers - 1
      if self._ctx.savers == 0 then
        OrgState._ctx.saved = true
        OrgState._ctx.dirty = false
      end
    end)
    :catch(function(err_msg)
      self._ctx.savers = self._ctx.savers - 1
      vim.schedule_wrap(function()
        utils.echo_warning('Failed to save current state! Error: ' .. err_msg)
      end)
    end)
end

---Synchronously save the state into cache
---@param timeout? number How long to wait for the save operation
function OrgState:save_sync(timeout)
  OrgState._ctx.saved = false
  self:save()
  vim.wait(timeout or 500, function()
    return OrgState._ctx.saved
  end, 20)
end

---Load the state cache into the current state
---@return OrgPromise
function OrgState:load()
  --- If we currently have a loading operation already running, return that
  --- promise. This avoids a race condition of sorts as without this there's
  --- potential to have two OrgState:load operations occuring and whichever
  --- finishes last sets the state. Not desirable.
  if self._ctx.curr_loader ~= nil then
    return self._ctx.curr_loader
  end

  --- If we've already loaded the state from cache we don't need to do so again
  if self._ctx.loaded then
    return Promise.resolve(self)
  end

  self._ctx.curr_loader = utils
    .readfile(cache_path, { raw = true })
    :next(function(data)
      local success, decoded = pcall(vim.json.decode, data, {
        luanil = { object = true, array = true },
      })
      if not success then
        local err_msg = vim.deepcopy(decoded)
        vim.schedule(function()
          utils.echo_warning('OrgState cache load failure, error: ' .. vim.inspect(err_msg))
          -- Try to 'repair' the cache by saving the current state
          self._ctx.dirty = true
          self:save()
        end)
      end
      -- Because the state cache repair happens potentially after the data has
      -- been added to the cache, we need to ensure the decoded table is set to
      -- empty if we got an error back on the json decode operation.
      if type(decoded) ~= 'table' then
        decoded = {}
      end

      -- It is possible that while the state was loading from cache values
      -- were saved into the state. We want to preference the newer values in
      -- the state and still get whatever values may not have been set in the
      -- interim of the load operation.
      self.data = vim.tbl_deep_extend('force', decoded, self.data)
      self._ctx.curr_loader = nil
      return self
    end)
    :catch(function(err)
      -- If the file didn't exist then go ahead and save
      -- our current cache and as a side effect create the file
      if type(err) == 'string' and err:match([[^ENOENT.*]]) then
        self._ctx.dirty = true
        self:save()
        return self
      end
      -- If the file did exist, something is wrong. Kick this to the top
      error(err)
    end)
    :finally(function()
      self._ctx.loaded = true
      self._ctx.curr_loader = nil
      self._ctx.dirty = false
    end)

  return self._ctx.curr_loader
end

---Synchronously load the state from cache if it hasn't been loaded
---@param timeout? number How long to wait for the cache load before erroring
---@return OrgState
function OrgState:load_sync(timeout)
  local state
  local err
  self
    :load()
    :next(function(loaded_state)
      state = loaded_state
    end)
    :catch(function(reject)
      err = reject
    end)

  vim.wait(timeout or 500, function()
    return state ~= nil or err ~= nil
  end, 20)

  if err then
    error(err)
  end

  if err == nil and state == nil then
    error('Did not load OrgState in time')
  end

  return state
end

---Reset the current state to empty
---@param overwrite? boolean Whether or not the cache should also be wiped
function OrgState:wipe(overwrite)
  overwrite = overwrite or false

  self.data = {}
  self._ctx.curr_loader = nil
  self._ctx.loaded = false
  self._ctx.saved = false
  self._ctx.dirty = true
  if overwrite then
    state:save_sync()
  end
end

return OrgState.new()

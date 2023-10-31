local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')

local State = { data = {}, _ctx = { loaded = false, curr_loader = nil } }

local cache_path = vim.fs.normalize(vim.fn.stdpath('cache') .. '/org-cache.json', { expand_env = false })
--- Returns the current State singleton
function State:new()
  -- This is done so we can later iterate the 'data'
  -- subtable cleanly and shove it into a cache
  setmetatable(State, {
    __index = function(tbl, key)
      return tbl.data[key]
    end,
    __newindex = function(tbl, key, value)
      tbl.data[key] = value
    end,
  })
  -- Start trying to load the state from cache as part of initializing the state
  self:load()
  return self
end

---Save the current state to cache
---@return Promise
function State:save()
  --- We want to ensure the state was loaded before saving.
  return self:load():next(function(_)
    utils.writefile(cache_path, vim.json.encode(State.data)):next(function(_) end, function(err_msg)
      vim.schedule_wrap(function()
        vim.notify('Failed to save current state! Error: ' .. err_msg, vim.log.levels.WARN, { title = 'Orgmode' })
      end)
    end)
  end, function(_) end)
end

---Load the state cache into the current state
---@return Promise
function State:load()
  --- If we currently have a loading operation already running, return that
  --- promise. This avoids a race condition of sorts as without this there's
  --- potential to have two State:load operations occuring and whichever
  --- finishes last sets the state. Not desirable.
  if self._ctx.curr_loader ~= nil then
    return self._ctx.curr_loader
  end

  --- If we've already loaded the state from cache we don't need to do so again
  if self._ctx.loaded then
    return Promise.new(function(resolve, _)
      return resolve()
    end)
  end

  self._ctx.curr_loader = utils.readfile(cache_path, { raw = true }):next(
    function(data)
      local success, decoded = pcall(vim.json.decode, data, {
        luanil = { object = true, array = true },
      })
      self._ctx.curr_loader = nil
      if not success then
        vim.schedule(function()
          vim.notify('State cache load failure, error: ' .. decoded, vim.log.levels.WARN, {
            title = 'Orgmode',
          })
          -- Try to 'repair' the cache by saving the current state
          self:save()
        end)
      end
      -- Because the state cache repair happens potentially after the data has
      -- been added to the cache, we need to ensure the decoded table is set to
      -- empty if we got an error back on the json decode operation.
      if type(decoded) ~= 'table' then
        decoded = {}
      end

      self._ctx.loaded = true
      -- It is possible that while the state was loading from cache values
      -- were saved into the state. We want to preference the newer values in
      -- the state and still get whatever values may not have been set in the
      -- interim of the load operation.
      self.data = vim.tbl_deep_extend('force', decoded, self.data)
      return self
    end, ---@param err string
    function(err)
      -- If the file didn't exist then go ahead and save
      -- our current cache and as a side effect create the file
      if type(err) == 'string' and err:match([[^ENOENT.*]]) then
        self:save()
      else
        -- If the file did exist, something is wrong. Kick this to the top
        error(err)
      end
    end
  )

  return self._ctx.curr_loader
end

return State:new()

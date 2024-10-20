-- NOTE: Be aware of https://github.com/neovim/neovim/issues/21469. Upstream *might* decide to
-- deprecate this, seems unlikely but something to keep an eye on.
local watchers = {}
local M = {}

---@param change_dict { old?: any, new: any }
---@param key string
---@param dict table
function M.dict_changed(change_dict, key, dict)
  if watchers[key] then
    watchers[key](change_dict, key, dict)
  end
end

---@param key string
---@param callback fun(change_dict: { old?: any, new: any }, key: string, dict: table)
function M.watch_buffer_variable(key, callback)
  vim.cmd(([[
    call dictwatcheradd(b:, '%s', 'OrgmodeWatchDictChanges')
  ]]):format(key))
  watchers[key] = callback
end

---@param key string
function M.unwatch_buffer_variable(key)
  vim.cmd(([[
    call dictwatcherdel(b:, '%s', 'OrgmodeWatchDictChanges')
  ]]):format(key))
  watchers[key] = nil
end

return M

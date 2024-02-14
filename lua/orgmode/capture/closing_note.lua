local utils = require('orgmode.utils')
local config = require('orgmode.config')
local Promise = require('orgmode.utils.promise')

---@class OrgClosingNote
local ClosingNote = {}

function ClosingNote:new()
  local data = {}
  setmetatable(data, self)
  self.__index = self
  return data
end

function ClosingNote:open()
  self._resolve_fn = nil
  self._close_tmp = utils.open_tmp_org_window(16, config.win_split_mode, config.win_border)
  config:setup_mappings('note')
  vim.api.nvim_buf_set_var(0, 'org_note', true)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { '# Insert note for closed todo item', '', '' })
  vim.schedule(function()
    vim.cmd('normal! G')
    vim.cmd('startinsert')
  end)

  return Promise.new(function(resolve)
    self._resolve_fn = resolve
  end)
end

function ClosingNote:refile()
  local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if content[1] and content[1]:match('#%s+') then
    content = { unpack(content, 2) }
  end
  if content[1] and vim.trim(content[1]) == '' then
    content = { unpack(content, 2) }
  end
  local fn = self._resolve_fn
  self._resolve_fn = nil
  self:kill()
  fn(content)
end

function ClosingNote:kill()
  if self._close_tmp then
    self._close_tmp()
    self._close_tmp = nil
    if self._resolve_fn then
      local fn = self._resolve_fn
      self._resolve_fn = nil
      fn(nil)
    end
  end
end

return ClosingNote

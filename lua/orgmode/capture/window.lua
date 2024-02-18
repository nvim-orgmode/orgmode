local config = require('orgmode.config')
local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')

---@class OrgCaptureWindowOpts
---@field template OrgCaptureTemplate
---@field on_open? fun()
---@field on_finish? fun(lines: string[]): string[]
---@field on_close? fun()

---@class OrgCaptureWindow :OrgCaptureWindowOpts
---@field private _window fun() | nil
---@field private _bufnr number
local CaptureWindow = {}
CaptureWindow.__index = CaptureWindow

---@param opts OrgCaptureWindowOpts
function CaptureWindow:new(opts)
  local data = {
    template = opts.template,
    on_open = opts.on_open,
    on_finish = opts.on_finish,
    on_close = opts.on_close,
  }
  return setmetatable(data, CaptureWindow)
end

---
function CaptureWindow:open()
  if self._window then
    return self:focus()
  end
  self._resolve_fn = nil
  local content = self.template:compile()
  self._window = utils.open_tmp_org_window(16, config.win_split_mode, config.win_border, self.on_close)
  vim.api.nvim_buf_set_lines(0, 0, -1, true, content)
  self.template:setup()
  vim.b.org_capture = true
  self._bufnr = vim.api.nvim_get_current_buf()

  if self.on_open then
    self.on_open()
  end

  return Promise.new(function(resolve)
    self._resolve_fn = resolve
  end)
end

function CaptureWindow:finish()
  local result = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if self.on_finish then
    result = self.on_finish(result)
  end
  local fn = self._resolve_fn
  self._resolve_fn = nil
  self:kill()
  fn(result)
end

function CaptureWindow:focus()
  if self._bufnr then
    local win = vim.fn.bufwinnr(self._bufnr)
    if win > -1 then
      vim.cmd(('%dwincd w'):format(win))
    end
  end
  return self
end

function CaptureWindow:kill()
  if self._window then
    self:_window()
    self._window = nil
    self._bufnr = nil
    if self._resolve_fn then
      local fn = self._resolve_fn
      self._resolve_fn = nil
      fn(nil)
    end
  end
end

return CaptureWindow

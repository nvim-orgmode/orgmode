local config = require('orgmode.config')
local utils = require('orgmode.utils')

---@class OrgCaptureWindowOpts
---@field template OrgCaptureTemplate
---@field on_open? fun()
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
    on_close = opts.on_close,
  }
  return setmetatable(data, CaptureWindow)
end

---
function CaptureWindow:open()
  if self._window then
    return self:focus()
  end
  local content = self.template:compile()
  self._window = utils.open_tmp_org_window(16, config.win_split_mode, config.win_border, self.on_close)
  vim.api.nvim_buf_set_lines(0, 0, -1, true, content)
  self.template:setup()
  vim.b.org_capture = true
  self._bufnr = vim.api.nvim_get_current_buf()

  if self.on_open then
    self.on_open()
  end

  return self
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
  end
end

return CaptureWindow

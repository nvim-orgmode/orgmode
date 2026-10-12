local config = require('orgmode.config')
local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')
local id_counter = 0

---@class OrgCaptureWindowOpts
---@field template OrgCaptureTemplate
---@field on_open? fun(self: OrgCaptureWindow)
---@field on_finish? fun(lines: string[]): string[] | nil
---@field on_close? fun(self: OrgCaptureWindow, event: string)
---Path of a new file to capture into directly, instead of a temp buffer
---@field resolve_file_target? fun(self: OrgCaptureWindow, content: string[]): string?

---@class OrgCaptureWindow :OrgCaptureWindowOpts
---@field id number
---@field pre_refile_done? boolean
---@field mappings? { mode: string, lhs: string }[] buffer mappings the capture added
---@field private _window fun() | nil
---@field private _bufnr number
---@field private _file_target? string
local CaptureWindow = {}
CaptureWindow.__index = CaptureWindow

---@param opts OrgCaptureWindowOpts
function CaptureWindow:new(opts)
  local data = {
    template = opts.template,
    on_open = opts.on_open,
    on_finish = opts.on_finish,
    on_close = opts.on_close,
    resolve_file_target = opts.resolve_file_target,
  }
  data.id = id_counter
  id_counter = id_counter + 1
  return setmetatable(data, CaptureWindow)
end

function CaptureWindow:open()
  if self._window then
    return self:focus()
  end
  self._resolve_fn = nil
  return self.template:compile():next(function(content)
    if not content then
      return utils.echo_info('Canceled.')
    end
    self._file_target = self.resolve_file_target and self.resolve_file_target(self, content) or nil
    if self._file_target then
      vim.fn.mkdir(vim.fn.fnamemodify(self._file_target, ':h'), 'p')
    end
    self:_open_buffer(content, self._file_target)
    self.template:setup()
    self:_attach()

    return Promise.new(function(resolve)
      self._resolve_fn = resolve
    end)
  end)
end

---Open the capture again after its buffer was closed, with the same content
---and cursor, marked as modified. Must be called while the old buffer still
---exists; the window opens once the old buffer is gone.
function CaptureWindow:reopen()
  local bufnr = self._bufnr
  local name = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cursor = vim.api.nvim_buf_get_mark(bufnr, '"')
  vim.schedule(function()
    -- Detach from the closed buffer and return to the window the capture
    -- was opened from.
    self:_window()
    self:_open_buffer(lines, name)
    vim.bo.modified = true
    self:_attach()
    pcall(vim.api.nvim_win_set_cursor, 0, cursor)
  end)
end

---@private
---@param lines string[]
---@param name? string
function CaptureWindow:_open_buffer(lines, name)
  self._window = utils.open_tmp_org_window(16, config.win_split_mode, config.win_border, self:_on_close(), name)
  if name and vim.fn.filereadable(name) == 1 then
    -- A float only names its new buffer after the file without reading it,
    -- and writing such a buffer over an existing file fails with E13.
    vim.cmd('silent edit!')
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
end

---@private
function CaptureWindow:_attach()
  vim.b.org_capture = true
  vim.b.org_capture_window_id = self.id
  self._bufnr = vim.api.nvim_get_current_buf()

  if self.on_open then
    self.on_open(self)
  end
end

function CaptureWindow:_on_close()
  if not self.on_close then
    return nil
  end
  return function(args)
    self.on_close(self, args.event)
  end
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

---@return boolean
function CaptureWindow:is_modified()
  return vim.bo[self._bufnr].modified
end

---@return number
function CaptureWindow:get_bufnr()
  return self._bufnr
end

---The new file this capture edits directly, or nil for a capture in a temp buffer.
---@return string | nil
function CaptureWindow:get_file_target()
  return self._file_target
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

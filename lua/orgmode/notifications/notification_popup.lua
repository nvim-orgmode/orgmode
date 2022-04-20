local NotificationPopup = {}

function NotificationPopup:new(opts)
  local data = {
    content = opts.content or nil,
    hide_after = opts.hide_after or 15000,
    buf = nil,
    win = nil,
  }
  setmetatable(data, self)
  self.__index = self
  data:show()
  return data
end

function NotificationPopup:show()
  if not self.content or self.content == '' then
    return
  end
  local opts = {
    relative = 'editor',
    width = 50,
    height = #self.content,
    style = 'minimal',
    border = 'single',
    anchor = 'NE',
    row = 0,
    col = vim.o.columns - 1,
    focusable = true,
  }
  self.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, true, self.content)
  vim.api.nvim_buf_set_option(self.buf, 'filetype', 'org')
  vim.api.nvim_buf_set_option(self.buf, 'bufhidden', 'wipe')
  self.win = vim.api.nvim_open_win(self.buf, false, opts)
  vim.api.nvim_win_set_option(self.win, 'winhl', 'Normal:Normal')
  vim.defer_fn(function()
    pcall(vim.api.nvim_win_close, self.win, true)
  end, self.hide_after)
  local notifications_augroup = vim.api.nvim_create_augroup('org_notification', { clear = true })
  vim.api.nvim_create_autocmd('BufEnter', {
    buffer = self.buf,
    group = notifications_augroup,
    command = 'bw!',
    once = true,
  })
end

return NotificationPopup

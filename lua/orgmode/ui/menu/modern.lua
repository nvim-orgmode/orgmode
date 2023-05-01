local ModernMenu = {}

function ModernMenu:new(config)
  config = config or {}

  local opts = {}
  opts.window = config.window
  opts.icons = config.icons

  setmetatable(opts, self)
  self.__index = self
  return opts
end

function ModernMenu:_get_window_margins()
  local margins = {}

  for i, m in ipairs(self.window.margin) do
    if m > 0 and m < 1 then
      if i % 2 == 0 then
        m = math.floor(vim.o.columns * m)
      else
        m = math.floor(vim.o.lines * m)
      end
    end
    margins[i] = m
  end

  return margins
end

function ModernMenu:_add_vertical_padding(content, size)
  for _ = 1, size do
    table.insert(content, '')
  end
end

function ModernMenu:_process_items(items)
  local pad_top, pad_right, pad_bot, pad_left = unpack(self.window.padding)

  local content = {}
  local keys = {}

  self:_add_vertical_padding(content, pad_top)

  for _, item in ipairs(items) do
    if item.key then
      keys[item.key] = item

      table.insert(
        content,
        string.rep(' ', pad_left)
          .. vim.fn.join({ item.key, self.icons.separator, item.label })
          .. string.rep(' ', pad_right)
      )
    end
  end

  self:_add_vertical_padding(content, pad_bot)

  return keys, content
end

function ModernMenu:_open_window(title, content)
  local margins = self:_get_window_margins()
  local wins = vim.tbl_filter(function(w)
    return vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_config(w).relative == ''
  end, vim.api.nvim_list_wins())

  self.buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(self.buffer, 0, -1, true, content)

  local window = vim.api.nvim_open_win(self.buffer, false, {
    title = title,
    title_pos = self.window.title_pos,
    relative = 'editor',
    width = vim.o.columns
      - margins[2]
      - margins[4]
      - (vim.fn.has('nvim-0.6') == 0 and self.window.border ~= 'none' and 2 or 0),
    height = #content,
    focusable = false,
    anchor = 'SW',
    border = self.window.border,
    row = vim.o.lines
      - margins[3]
      + ((vim.o.laststatus == 0 or vim.o.laststatus == 1 and #wins == 1) and 1 or 0)
      - vim.o.cmdheight,
    col = margins[4],
    style = 'minimal',
    noautocmd = true,
    zindex = self.window.zindex,
  })
  vim.cmd.redraw()
  return window
end

function ModernMenu:_close()
  vim.api.nvim_win_close(self.window, true)
  vim.api.nvim_buf_delete(self.buffer, { force = true })
  vim.cmd.redraw()
end

function ModernMenu:open(title, items)
  local keys, content = self:_process_items(items)
  self.window = self:_open_window(title, content)

  local char = vim.fn.nr2char(vim.fn.getchar())
  self:_close()

  local entry = keys[char]
  if entry and entry.action then
    return entry.action()
  end
end

return ModernMenu

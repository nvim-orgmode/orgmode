local Date = require('orgmode.objects.date')
local utils = require('orgmode.utils')
---@class Calendar
---@field win number
---@field buf number
---@field callback function
---@field namespace function
---@field date Date
---@field month Date

local Calendar = {
  win = nil,
  buf = nil,
  callback = nil,
  namespace = vim.api.nvim_create_namespace('org_calendar'),
  date = nil,
  month = Date.today():start_of('month')
}

vim.cmd[[hi default link OrgCalendarToday DiffText]]

---@param data table
function Calendar.new(data)
  data = data or {}
  Calendar.callback = data.callback
  if data.date then
    Calendar.date = data.date
    Calendar.month = data.date:set({ day = 1 })
  end
  return Calendar
end

function Calendar.open()
  local opts = {
    relative = 'editor',
    width = 36,
    height = 10,
    style = 'minimal',
    border = 'single',
    row = vim.o.lines / 2 - 4,
    col = vim.o.columns / 2 - 20,
  }

  Calendar.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(Calendar.buf, 'orgcalendar')
  Calendar.win = vim.api.nvim_open_win(Calendar.buf, true, opts)

  vim.cmd[[autocmd BufWipeout <buffer> lua require('orgmode.objects.calendar').dispose()]]

  Calendar.render()

  vim.api.nvim_win_set_option(Calendar.win, 'winhl', 'Normal:Normal')
  vim.api.nvim_win_set_option(Calendar.win, 'wrap', false)
  vim.api.nvim_win_set_option(Calendar.win, 'scrolloff', 0)
  vim.api.nvim_win_set_option(Calendar.win, 'sidescrolloff', 0)
  vim.api.nvim_buf_set_var(Calendar.buf, 'indent_blankline_enabled', false)
  vim.api.nvim_buf_set_option(Calendar.buf, 'bufhidden', 'wipe')

  utils.buf_keymap(Calendar.buf, 'n', '>', '<cmd>lua require("orgmode.objects.calendar").forward()<CR>')
  utils.buf_keymap(Calendar.buf, 'n', '<', '<cmd>lua require("orgmode.objects.calendar").backward()<CR>')
  utils.buf_keymap(Calendar.buf, 'n', '<CR>', '<cmd>lua require("orgmode.objects.calendar").select()<CR>')
  utils.buf_keymap(Calendar.buf, 'n', '.', '<cmd>lua require("orgmode.objects.calendar").reset()<CR>')
  utils.buf_keymap(Calendar.buf, 'n', 'q', ':bw!<CR>')
  utils.buf_keymap(Calendar.buf, 'n', '<Esc>', ':bw!<CR>')
  local search_day = Date.today():format('%d')
  if Calendar.date then
    search_day = Calendar.date:format('%d')
  end
  vim.fn.cursor(2, 0)
  vim.fn.search(search_day, 'W')
end

function Calendar.render()
  local first_row = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'}
  local content = { {}, {}, {}, {}, {}, {} }
  local start_weekday = Calendar.month:get_isoweekday()
  while start_weekday > 1 do
    table.insert(content[1], '  ')
    start_weekday = start_weekday - 1
  end
  local today = Date.today()
  local is_today_month = today:is_same(Calendar.month, 'month')
  local dates = Calendar.month:get_range_until(Calendar.month:end_of('month'))
  local month = Calendar.month:format('%B %Y')
  month = string.rep(' ', math.floor((36 - month:len()) / 2))..month
  local start_row = 1
  for _, date in ipairs(dates) do
    table.insert(content[start_row], date:format('%d'))
    if #content[start_row] % 7 == 0 then
      start_row = start_row + 1
    end
  end
  local value = vim.tbl_map(function(item)
    return ' '..table.concat(item, ' | ')
  end, content)
  first_row = ' '..table.concat(first_row, '  ')
  table.insert(value, 1, first_row)
  table.insert(value, 1, month)
  table.insert(value, ' [<] - prev month  [>] - next month')
  table.insert(value, ' [.] - today   [Enter] - select day')

  vim.api.nvim_buf_set_lines(Calendar.buf, 0, -1, true, value)
  vim.api.nvim_buf_clear_namespace(Calendar.buf, Calendar.namespace, 0, -1)
  vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'Comment', #value - 2, 0, -1)
  vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'Comment', #value - 1, 0, -1)
  if is_today_month then
    local day_formatted = today:format('%d')
    for i, line in ipairs(value) do
      local from, to = line:find(day_formatted)
      if from and to then
        vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'OrgCalendarToday', i - 1, from - 2, to + 1)
      end
    end
  end
end

function Calendar.forward()
  Calendar.month = Calendar.month:add({ month = 1 })
  Calendar.render()
end

function Calendar.backward()
  Calendar.month = Calendar.month:subtract({ month = 1 })
  Calendar.render()
end

function Calendar.reset()
  Calendar.month = Date.today():start_of('month')
  Calendar.render()
  vim.fn.cursor(2, 0)
  vim.fn.search(Date.today():format('%d'), 'W')
end

function Calendar:select()
  local day = vim.trim(vim.fn.expand('<cword>'))
  local line = vim.fn.line('.')
  if line < 3 or not day:match('%d+') then
    return utils.echo_warning('Please select valid day number.')
  end
  day = tonumber(day)
  local selected_date = Calendar.month:set({ day = day })
  local cb = Calendar.callback
  vim.cmd[[bw!]]
  if type(cb) == 'function' then
    cb(selected_date)
  end
end

function Calendar.dispose()
  Calendar.win = nil
  Calendar.buf = nil
  Calendar.callback = nil
  Calendar.month = Date.today():start_of('month')
end

return Calendar

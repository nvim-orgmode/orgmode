local Date = require('orgmode.objects.date')
local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')
local config = require('orgmode.config')
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
  namespace = vim.api.nvim_create_namespace('org_calendar'),
  date = nil,
  month = Date.today():start_of('month'),
}

vim.cmd([[hi OrgCalendarToday gui=reverse cterm=reverse]])

---@param data table
function Calendar.new(data)
  data = data or {}
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

  local calendar_augroup = vim.api.nvim_create_augroup('org_calendar', { clear = true })
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = Calendar.buf,
    group = calendar_augroup,
    callback = function()
      require('orgmode.objects.calendar').dispose()
    end,
    once = true,
  })

  Calendar.render()

  vim.api.nvim_win_set_option(Calendar.win, 'winhl', 'Normal:Normal')
  vim.api.nvim_win_set_option(Calendar.win, 'wrap', false)
  vim.api.nvim_win_set_option(Calendar.win, 'scrolloff', 0)
  vim.api.nvim_win_set_option(Calendar.win, 'sidescrolloff', 0)
  vim.api.nvim_buf_set_var(Calendar.buf, 'indent_blankline_enabled', false)
  vim.api.nvim_buf_set_option(Calendar.buf, 'bufhidden', 'wipe')

  local map_opts = { buffer = Calendar.buf, silent = true }

  vim.keymap.set('n', 'j', '<cmd>lua require("orgmode.objects.calendar").cursor_down()<cr>', map_opts)
  vim.keymap.set('n', 'k', '<cmd>lua require("orgmode.objects.calendar").cursor_up()<cr>', map_opts)
  vim.keymap.set('n', 'h', '<cmd>lua require("orgmode.objects.calendar").cursor_left()<cr>', map_opts)
  vim.keymap.set('n', 'l', '<cmd>lua require("orgmode.objects.calendar").cursor_right()<cr>', map_opts)
  vim.keymap.set('n', '>', '<cmd>lua require("orgmode.objects.calendar").forward()<CR>', map_opts)
  vim.keymap.set('n', '<', '<cmd>lua require("orgmode.objects.calendar").backward()<CR>', map_opts)
  vim.keymap.set('n', '<CR>', '<cmd>lua require("orgmode.objects.calendar").select()<CR>', map_opts)
  vim.keymap.set('n', '.', '<cmd>lua require("orgmode.objects.calendar").reset()<CR>', map_opts)
  vim.keymap.set('n', 'q', ':call nvim_win_close(win_getid(), v:true)<CR>', map_opts)
  vim.keymap.set('n', '<Esc>', ':call nvim_win_close(win_getid(), v:true)<CR>', map_opts)
  local search_day = Date.today():format('%d')
  if Calendar.date then
    search_day = Calendar.date:format('%d')
  end
  vim.fn.cursor({ 2, 0 })
  vim.fn.search(search_day, 'W')
  return Promise.new(function(resolve)
    Calendar.callback = resolve
  end)
end

function Calendar.render()
  vim.api.nvim_buf_set_option(Calendar.buf, 'modifiable', true)
  local start_from_sunday = config.calendar_week_start_day == 0

  local first_row = { 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' }
  if start_from_sunday then
    first_row = { 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' }
  end
  local content = { {}, {}, {}, {}, {}, {} }
  local start_weekday = Calendar.month:get_isoweekday()
  if start_from_sunday then
    start_weekday = Calendar.month:get_weekday()
  end
  while start_weekday > 1 do
    table.insert(content[1], '  ')
    start_weekday = start_weekday - 1
  end
  local today = Date.today()
  local is_today_month = today:is_same(Calendar.month, 'month')
  local dates = Calendar.month:get_range_until(Calendar.month:end_of('month'))
  local month = Calendar.month:format('%B %Y')
  month = string.rep(' ', math.floor((36 - month:len()) / 2)) .. month
  local start_row = 1
  for _, date in ipairs(dates) do
    table.insert(content[start_row], date:format('%d'))
    if #content[start_row] % 7 == 0 then
      start_row = start_row + 1
    end
  end
  local value = vim.tbl_map(function(item)
    return ' ' .. table.concat(item, '   ') .. ' '
  end, content)
  first_row = ' ' .. table.concat(first_row, '  ')
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
      local from, to = line:find('%s' .. day_formatted .. '%s')
      if from and to then
        vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'OrgCalendarToday', i - 1, from - 1, to)
      end
    end
  end

  vim.api.nvim_buf_set_option(Calendar.buf, 'modifiable', false)
end

function Calendar.forward()
  Calendar.month = Calendar.month:add({ month = 1 })
  Calendar.render()
  vim.fn.cursor({ 2, 0 })
  vim.fn.search('01')
end

function Calendar.backward()
  Calendar.month = Calendar.month:subtract({ month = 1 })
  Calendar.render()
  vim.fn.cursor('$', 0)
  vim.fn.search([[\d\d]], 'b')
end

function Calendar.cursor_right()
  for i = 1, vim.v.count1 do
    local line, col = vim.fn.line('.'), vim.fn.col('.')
    local curr_line = vim.fn.getline('.')
    local offset = curr_line:sub(col + 1, #curr_line):find('%d%d')
    if offset ~= nil then
      vim.fn.cursor({ line, col + offset })
    end
  end
end

function Calendar.cursor_left()
  for i = 1, vim.v.count1 do
    local line, col = vim.fn.line('.'), vim.fn.col('.')
    local curr_line = vim.fn.getline('.')
    local _, offset = curr_line:sub(1, col - 1):find('.*%d%d')
    if offset ~= nil then
      vim.fn.cursor(line, offset)
    end
  end
end

function Calendar.cursor_up()
  for i = 1, vim.v.count1 do
    local line, col = vim.fn.line('.'), vim.fn.col('.')
    if line > 9 then
      vim.fn.cursor(line - 1, col)
      return
    end

    local prev_line = vim.fn.getline(line - 1)
    local first_num = prev_line:find('%d%d')
    if first_num == nil then
      return
    end

    local move_to
    if first_num > col then
      move_to = first_num
    else
      move_to = col
    end
    vim.fn.cursor(line - 1, move_to)
  end
end

function Calendar.cursor_down()
  for i = 1, vim.v.count1 do
    local line, col = vim.fn.line('.'), vim.fn.col('.')
    if line <= 1 then
      vim.fn.cursor(line + 1, col)
      return
    end

    local next_line = vim.fn.getline(line + 1)
    local _, last_num = next_line:find('.*%d%d')
    if last_num == nil then
      return
    end

    local move_to
    if last_num < col then
      move_to = last_num
    else
      move_to = col
    end
    vim.fn.cursor(line + 1, move_to)
  end
end

function Calendar.reset()
  local today = Calendar.month:set_todays_date()
  Calendar.month = today:set({ day = 1 })
  Calendar.render()
  vim.fn.cursor(2, 0)
  vim.fn.search(today:format('%d'), 'W')
end

function Calendar.select()
  local col = vim.fn.col('.')
  local char = vim.fn.getline('.'):sub(col, col)
  local day = vim.trim(vim.fn.expand('<cword>'))
  local line = vim.fn.line('.')
  vim.cmd([[redraw!]])
  if line < 3 or not char:match('%d') then
    return utils.echo_warning('Please select valid day number.', nil, false)
  end
  day = tonumber(day)
  local selected_date = Calendar.month:set({ day = day })
  local cb = Calendar.callback
  Calendar.callback = nil
  vim.cmd([[echon]])
  vim.api.nvim_win_close(0, true)
  return cb(selected_date)
end

function Calendar.dispose()
  Calendar.win = nil
  Calendar.buf = nil
  Calendar.month = Date.today():start_of('month')
  if Calendar.callback then
    Calendar.callback(nil)
    Calendar.callback = nil
  end
end

return Calendar

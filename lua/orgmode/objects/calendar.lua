local Date = require('orgmode.objects.date')
local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')
local config = require('orgmode.config')
--
local SelState = { DAY = 0, HOUR = 1, MIN_BIG = 2, MIN_SMALL = 3 }
local big_minute_step = config.org_time_picker_min_big
local small_minute_step = config.org_time_stamp_rounding_minutes

---@class OrgCalendar
---@field win number?
---@field buf number?
---@field callback function
---@field namespace function
---@field date Date?
---@field month Date
---@field selected Date?
---@field select_state integer
local Calendar = {
  win = nil,
  buf = nil,
  namespace = vim.api.nvim_create_namespace('org_calendar'),
  date = nil,
  month = Date.today():start_of('month'),
  selected = nil,
  select_state = SelState.DAY,
  clearable = false,
}

vim.cmd([[hi default OrgCalendarToday gui=reverse cterm=reverse]])
vim.cmd([[hi default OrgCalendarSelected gui=underline cterm=underline]])

---@param data table
function Calendar.new(data)
  data = data or {}
  if data.date then
    Calendar.month = data.date:set({ day = 1 })
    Calendar.date = data.date
  end
  Calendar.clearable = data.clearable
  return Calendar
end

local width = 36
local height = 13
local x_offset = 1 -- one border cell
local y_offset = 2 -- one border cell and one padding cell

function Calendar.open()
  local opts = {
    relative = 'editor',
    width = width,
    height = Calendar.clearable and height + 1 or height,
    style = 'minimal',
    border = config.win_border,
    row = vim.o.lines / 2 - (y_offset + height) / 2,
    col = vim.o.columns / 2 - (x_offset + width) / 2,
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

  vim.api.nvim_set_option_value('winhl', 'Normal:Normal', { win = Calendar.win })
  vim.api.nvim_set_option_value('wrap', false, { win = Calendar.win })
  vim.api.nvim_set_option_value('scrolloff', 0, { win = Calendar.win })
  vim.api.nvim_set_option_value('sidescrolloff', 0, { win = Calendar.win })
  vim.api.nvim_buf_set_var(Calendar.buf, 'indent_blankline_enabled', false)
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = Calendar.buf })

  local map_opts = { buffer = Calendar.buf, silent = true, nowait = true }

  vim.keymap.set('n', 'j', '<cmd>lua require("orgmode.objects.calendar").cursor_down()<cr>', map_opts)
  vim.keymap.set('n', 'k', '<cmd>lua require("orgmode.objects.calendar").cursor_up()<cr>', map_opts)
  vim.keymap.set('n', 'h', '<cmd>lua require("orgmode.objects.calendar").cursor_left()<cr>', map_opts)
  vim.keymap.set('n', 'l', '<cmd>lua require("orgmode.objects.calendar").cursor_right()<cr>', map_opts)
  vim.keymap.set('n', '>', '<cmd>lua require("orgmode.objects.calendar").forward()<CR>', map_opts)
  vim.keymap.set('n', '<', '<cmd>lua require("orgmode.objects.calendar").backward()<CR>', map_opts)
  vim.keymap.set('n', '<CR>', '<cmd>lua require("orgmode.objects.calendar").select()<CR>', map_opts)
  vim.keymap.set('n', '.', '<cmd>lua require("orgmode.objects.calendar").reset()<CR>', map_opts)
  vim.keymap.set('n', 'i', '<cmd>lua require("orgmode.objects.calendar").read_date()<CR>', map_opts)
  vim.keymap.set('n', 'q', ':call nvim_win_close(win_getid(), v:true)<CR>', map_opts)
  vim.keymap.set('n', '<Esc>', '<cmd>lua require("orgmode.objects.calendar").abort()<CR>', map_opts)
  if Calendar.clearable then
    vim.keymap.set('n', 'r', '<cmd>lua require("orgmode.objects.calendar").clear_date()<CR>', map_opts)
  end
  vim.keymap.set('n', 't', '<cmd>lua require("orgmode.objects.calendar").set_time()<cr>', map_opts)
  if Calendar.has_time() then
    vim.keymap.set('n', 'T', '<cmd>lua require("orgmode.objects.calendar").clear_time()<cr>', map_opts)
  end
  Calendar.jump_day(Date.today())
  return Promise.new(function(resolve)
    Calendar.callback = resolve
  end)
end

function Calendar.render()
  vim.api.nvim_set_option_value('modifiable', true, { buf = Calendar.buf })

  local cal_rows = { {}, {}, {}, {}, {}, {} } -- the calendar rows
  local start_from_sunday = config.calendar_week_start_day == 0
  local weekday_row = { 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' }

  if start_from_sunday then
    weekday_row = { 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' }
  end

  -- construct title (Month YYYY)
  local title = Calendar.month:format('%B %Y')
  title = string.rep(' ', math.floor((width - title:len()) / 2)) .. title

  -- insert whitespace before first day of month
  local start_weekday = Calendar.month:get_isoweekday()
  if start_from_sunday then
    start_weekday = Calendar.month:get_weekday()
  end
  while start_weekday > 1 do
    table.insert(cal_rows[1], '  ')
    start_weekday = start_weekday - 1
  end

  -- insert dates into cal_rows
  local dates = Calendar.month:get_range_until(Calendar.month:end_of('month'))
  local current_row = 1
  for _, date in ipairs(dates) do
    table.insert(cal_rows[current_row], date:format('%d'))
    if #cal_rows[current_row] % 7 == 0 then
      current_row = current_row + 1
    end
  end

  -- add spacing between the calendar cells
  local content = vim.tbl_map(function(item)
    return ' ' .. table.concat(item, '   ') .. ' '
  end, cal_rows)

  -- put it all together
  table.insert(content, 1, ' ' .. table.concat(weekday_row, '  '))
  table.insert(content, 1, title)

  table.insert(content, Calendar.render_time(Calendar.date))
  table.insert(content, '')

  -- TODO: redundant, since it's static data
  table.insert(content, ' [<] - prev month  [>] - next month')
  table.insert(content, ' [.] - today   [Enter] - select day')
  if Calendar.clearable then
    table.insert(content, ' [i] - enter date  [r] - clear date')
  else
    table.insert(content, ' [i] - enter date')
  end
  if Calendar.has_time() then
    table.insert(content, ' [t] - enter time  [T] - clear time')
  else
    table.insert(content, ' [t] - enter time')
  end

  vim.api.nvim_buf_set_lines(Calendar.buf, 0, -1, true, content)
  vim.api.nvim_buf_clear_namespace(Calendar.buf, Calendar.namespace, 0, -1)
  if not Calendar.has_time() then
    vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'Comment', 8, 0, -1)
  end
  vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'Comment', #content - 4, 0, -1)
  vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'Comment', #content - 3, 0, -1)
  vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'Comment', #content - 2, 0, -1)
  vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'Comment', #content - 1, 0, -1)

  -- highlight the cell of the current day
  Calendar.highlight_day(content, Date.today(), 'OrgCalendarToday')
  -- highlight selected day
  Calendar.highlight_day(content, Calendar.date, 'OrgCalendarSelected')

  vim.api.nvim_set_option_value('modifiable', false, { buf = Calendar.buf })
end

---@param day Date?
---@param hl_group string
function Calendar.highlight_day(content, day, hl_group)
  if not day then
    return
  end

  if not day:is_same(Calendar.month, 'month') then
    return
  end

  local day_formatted = day:format('%d')
  for i, line in ipairs(content) do
    local from, to = line:find('%s' .. day_formatted .. '%s')
    if from and to then
      vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, hl_group, i - 1, from - 1, to)
    end
  end
end

function Calendar.left_pad(time_part)
  return time_part < 10 and '0' .. time_part or time_part
end

---@param date Date
function Calendar.render_time(date)
  local l_pad = '               '
  local r_pad = '              '
  local hour_str = Calendar.has_time() and Calendar.left_pad(date.hour) or '--'
  local min_str = Calendar.has_time() and Calendar.left_pad(date.min) or '--'
  return l_pad .. hour_str .. ':' .. min_str .. r_pad
end

function Calendar.has_time()
  return not Calendar.date.date_only
end

function Calendar.forward()
  Calendar.month = Calendar.month:add({ month = vim.v.count1 })
  Calendar.render()
  vim.fn.cursor(2, 1)
  vim.fn.search('01')
  Calendar.render()
end

function Calendar.backward()
  Calendar.month = Calendar.month:subtract({ month = vim.v.count1 })
  Calendar.render()
  vim.fn.cursor(vim.fn.line('$'), 0)
  vim.fn.search([[\d\d]], 'b')
  Calendar.render()
end

function Calendar.cursor_right()
  if Calendar.select_state ~= SelState.DAY then
    if Calendar.select_state == SelState.HOUR then
      Calendar.set_sel_min10()
    elseif Calendar.select_state == SelState.MIN_BIG then
      Calendar.set_sel_min5()
    elseif Calendar.select_state == SelState.MIN_SMALL then
      Calendar.set_sel_hour()
    end
    return
  end
  for _ = 1, vim.v.count1 do
    local line, col = vim.fn.line('.'), vim.fn.col('.')
    local curr_line = vim.fn.getline('.')
    local offset = curr_line:sub(col + 1, #curr_line):find('%d%d')
    if offset ~= nil then
      vim.fn.cursor(line, col + offset)
    end
  end
  Calendar.date = Calendar.get_selected_date()
  Calendar.render()
end

function Calendar.cursor_left()
  if Calendar.select_state ~= SelState.DAY then
    if Calendar.select_state == SelState.HOUR then
      Calendar.set_sel_min5()
    elseif Calendar.select_state == SelState.MIN_BIG then
      Calendar.set_sel_hour()
    elseif Calendar.select_state == SelState.MIN_SMALL then
      Calendar.set_sel_min10()
    end
    return
  end
  for _ = 1, vim.v.count1 do
    local line, col = vim.fn.line('.'), vim.fn.col('.')
    local curr_line = vim.fn.getline('.')
    local _, offset = curr_line:sub(1, col - 1):find('.*%d%d')
    if offset ~= nil then
      vim.fn.cursor(line, offset)
    end
  end
  Calendar.date = Calendar.get_selected_date()
  Calendar.render()
end

---@param direction string
---@param step_size number
---@param current number
---@param count number
local function step_minute(direction, step_size, current, count)
  local sign = direction == 'up' and -1 or 1
  local residual = current % step_size
  local factor = (residual == 0 or direction == 'up') and count or count - 1
  return factor * step_size + sign * residual
end

--- Controls, how the hours are adjusted. The rounding the minutes can be disabled
--- by the user, so adjusting the hours just moves the time 1 our back or forth
---@param direction string
---@param current Date
---@param count number
---@return table
local function step_hour(direction, current, count)
  if not config.org_time_picker_round_min_with_hours or current.min % big_minute_step == 0 then
    return { hour = count, min = 0 }
  end

  -- if adjusting the mins would land on a full hour, we don't step a full hour,
  -- otherwise we do and round the minutes
  local sign = direction == 'up' and 1 or -1
  local min = step_minute(direction, big_minute_step, current.min, 1)
  local min_new = current.min + sign * min
  local hour = min_new % 60 ~= 0 and count or count - 1
  return { hour = hour, min = min }
end

function Calendar.cursor_up()
  if Calendar.select_state ~= SelState.DAY then
    -- to avoid unexpectedly changing the day we cache it ...
    local day = Calendar.date.day
    if Calendar.select_state == SelState.HOUR then
      Calendar.date = Calendar.date:add(step_hour('up', Calendar.date, vim.v.count1))
    elseif Calendar.select_state == SelState.MIN_BIG then
      Calendar.date = Calendar.date:add({ min = step_minute('up', big_minute_step, Calendar.date.min, vim.v.count1) })
    elseif Calendar.select_state == SelState.MIN_SMALL then
      Calendar.date = Calendar.date:add({ min = step_minute('up', small_minute_step, Calendar.date.min, vim.v.count1) })
    end
    -- and restore the cached day after adjusting the time
    Calendar.date = Calendar.date:set({ day = day })
    Calendar.rerender_time()
    return
  end
  for _ = 1, vim.v.count1 do
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
  Calendar.date = Calendar.get_selected_date()
  Calendar.render()
end

function Calendar.cursor_down()
  if Calendar.select_state ~= SelState.DAY then
    -- to avoid unexpectedly changing the day we cache it ...
    local day = Calendar.date.day
    if Calendar.select_state == SelState.HOUR then
      Calendar.date = Calendar.date:subtract(step_hour('down', Calendar.date, vim.v.count1))
    elseif Calendar.select_state == SelState.MIN_BIG then
      Calendar.date =
        Calendar.date:subtract({ min = step_minute('down', big_minute_step, Calendar.date.min, vim.v.count1) })
    elseif Calendar.select_state == SelState.MIN_SMALL then
      Calendar.date =
        Calendar.date:subtract({ min = step_minute('down', small_minute_step, Calendar.date.min, vim.v.count1) })
    end
    -- and restore the cached day after adjusting the time
    Calendar.date = Calendar.date:set({ day = day })
    Calendar.rerender_time()
    return
  end
  for _ = 1, vim.v.count1 do
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
  Calendar.date = Calendar.get_selected_date()
  Calendar.render()
end

function Calendar.reset()
  local today = Calendar.month:set_todays_date()
  Calendar.month = today:set({ day = 1 })
  Calendar.render()
  vim.fn.cursor(2, 1)
  vim.fn.search(today:format('%d'), 'W')
end

function Calendar.get_selected_date()
  if Calendar.select_state ~= SelState.DAY then
    return Calendar.date
  end
  local col = vim.fn.col('.')
  local char = vim.fn.getline('.'):sub(col, col)
  local day = tonumber(vim.trim(vim.fn.expand('<cword>')))
  local line = vim.fn.line('.')
  vim.cmd([[redraw!]])
  if line < 3 or not char:match('%d') then
    return utils.echo_warning('Please select valid day number.', nil, false)
  end
  return Calendar.date:set({
    month = Calendar.month.month,
    day = day,
    date_only = Calendar.date.date_only,
  })
end

function Calendar.select()
  local selected_date
  if Calendar.select_state == SelState.DAY then
    selected_date = Calendar.get_selected_date()
  else
    selected_date = Calendar.date:set({
      day = Calendar.date.day,
      hour = Calendar.date.hour,
      min = Calendar.date.min,
      date_only = false,
    })
  end
  local cb = Calendar.callback
  Calendar.callback = nil
  Calendar.select_state = SelState.DAY
  vim.cmd([[echon]])
  vim.api.nvim_win_close(0, true)
  return cb(selected_date)
end

function Calendar.abort()
  if Calendar.select_state == SelState.DAY then
    vim.cmd([[echon]])
    vim.api.nvim_win_close(0, true)
    Calendar.dispose()
  end
  Calendar.set_sel_day()
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

function Calendar.clear_date()
  local cb = Calendar.callback
  Calendar.callback = nil
  vim.cmd([[echon]])
  vim.api.nvim_win_close(0, true)
  cb(nil, true)
end

function Calendar.read_date()
  local default = Calendar.get_selected_date():to_string()
  vim.ui.input({ prompt = 'Enter date: ', default = default }, function(result)
    if result then
      local date = Date.from_string(result)
      if not date then
        date = Calendar.get_selected_date():adjust(result)
      end

      Calendar.date = date
      Calendar.month = date:set({ day = 1 })
      Calendar.render()
      vim.fn.cursor(2, 1)
      vim.fn.search(date:format('%d'), 'W')
    end
  end)
end

function Calendar.set_time()
  Calendar.date = Calendar.get_selected_date()
  Calendar.date = Calendar.date:set({ date_only = false })
  Calendar.render() -- because we want to highlight the currently selected date, we have to render everything
  Calendar.set_sel_hour()
end

function Calendar.rerender_time()
  vim.api.nvim_buf_set_option(Calendar.buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(Calendar.buf, 8, 9, true, { Calendar.render_time(Calendar.date) })
  if Calendar.has_time() then
    vim.api.nvim_buf_set_lines(Calendar.buf, 13, 14, true, { ' [t] - enter time  [T] - clear time' })
    vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'Normal', 8, 0, -1)
    vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'Comment', 13, 0, -1)
  else
    vim.api.nvim_buf_set_lines(Calendar.buf, 13, 14, true, { ' [t] - enter time' })
    vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'Comment', 8, 0, -1)
    vim.api.nvim_buf_add_highlight(Calendar.buf, Calendar.namespace, 'Comment', 13, 0, -1)
  end
  vim.api.nvim_buf_set_option(Calendar.buf, 'modifiable', false)
end

function Calendar.clear_time()
  Calendar.date = Calendar.date:set({ hour = 0, min = 0, date_only = true })
  Calendar.rerender_time()
  Calendar.set_sel_day()
end

function Calendar.set_sel_hour()
  Calendar.select_state = SelState.HOUR
  vim.fn.cursor({ 9, 16 })
end

function Calendar.set_sel_day()
  Calendar.select_state = SelState.DAY
  Calendar.jump_day(Calendar.date)
end

function Calendar.set_sel_min10()
  Calendar.select_state = SelState.MIN_BIG
  vim.fn.cursor({ 9, 19 })
end

function Calendar.set_sel_min5()
  Calendar.select_state = SelState.MIN_SMALL
  vim.fn.cursor({ 9, 20 })
end

function Calendar.jump_day(date)
  local search_day = date:format('%d')
  if Calendar.date then
    search_day = Calendar.date:format('%d')
  end
  vim.fn.cursor(2, 1)
  vim.fn.search(search_day, 'W')
end

return Calendar

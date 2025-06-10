local Date = require('orgmode.objects.date')
local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')
local config = require('orgmode.config')
local namespace = vim.api.nvim_create_namespace('org_calendar')
local colors = require('orgmode.colors')
local Range = require('orgmode.files.elements.range')
local Input = require('orgmode.ui.input')

---@alias OrgCalendarOnRenderDayOpts { line: number, from: number, to: number, buf: number, namespace: number }
---@alias OrgCalendarOnRenderDay fun(day: OrgDate, opts: OrgCalendarOnRenderDayOpts)

local SelState = { DAY = 0, HOUR = 1, MIN_BIG = 2, MIN_SMALL = 3 }
local big_minute_step = config.calendar.min_big_step
local small_minute_step = config.calendar.min_small_step or config.org_time_stamp_rounding_minutes

---@class OrgCalendar
---@field win number?
---@field buf number?
---@field callback fun(date: OrgDate | nil, cleared?: boolean)
---@field date OrgDate?
---@field title? string
---@field on_day? OrgCalendarOnRenderDay
---@field selected OrgDate?
---@field select_state integer
---@field clearable boolean
local Calendar = {
  win = nil,
  buf = nil,
  date = nil,
  selected = nil,
  select_state = SelState.DAY,
  clearable = false,
}
Calendar.__index = Calendar

vim.cmd([[hi default OrgCalendarToday gui=reverse cterm=reverse]])
vim.cmd([[hi default OrgCalendarSelected gui=underline cterm=underline]])

---@param data { date?: OrgDate, clearable?: boolean, title?: string, on_day?: OrgCalendarOnRenderDay }
function Calendar.new(data)
  data = data or {}
  local this = setmetatable({}, Calendar)
  this.clearable = data.clearable
  this.title = data.title
  this.on_day = data.on_day
  if data.date then
    this.date = data.date
  else
    this.date = Date.today()
  end
  return this
end

local width = 36
local height = 14
local x_offset = 1 -- one border cell
local y_offset = 2 -- one border cell and one padding cell

---@return OrgPromise<OrgDate | nil>
function Calendar:open()
  local get_window_opts = function()
    return {
      relative = 'editor',
      width = width,
      height = height,
      style = 'minimal',
      border = config.win_border,
      row = vim.o.lines / 2 - (y_offset + height) / 2,
      col = vim.o.columns / 2 - (x_offset + width) / 2,
      title = self.title or 'Calendar',
      title_pos = 'center',
    }
  end
  self.prev_win = vim.api.nvim_get_current_win()

  self.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(self.buf, 'orgcalendar')
  self.win = vim.api.nvim_open_win(self.buf, true, get_window_opts())

  local calendar_augroup = vim.api.nvim_create_augroup('org_calendar', { clear = true })
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = self.buf,
    group = calendar_augroup,
    callback = function()
      self:dispose()
    end,
    once = true,
  })

  vim.api.nvim_create_autocmd('VimResized', {
    buffer = self.buf,
    group = calendar_augroup,
    callback = function()
      if self.win then
        vim.api.nvim_win_set_config(self.win, get_window_opts())
      end
    end,
  })

  self:render()

  vim.api.nvim_set_option_value('winhl', 'Normal:Normal', { win = self.win })
  vim.api.nvim_set_option_value('wrap', false, { win = self.win })
  vim.api.nvim_set_option_value('scrolloff', 0, { win = self.win })
  vim.api.nvim_set_option_value('sidescrolloff', 0, { win = self.win })
  vim.api.nvim_buf_set_var(self.buf, 'indent_blankline_enabled', false)
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = self.buf })

  local map_opts = { buffer = self.buf, silent = true, nowait = true }

  vim.keymap.set('n', 'j', function()
    return self:cursor_down()
  end, map_opts)
  vim.keymap.set('n', 'k', function()
    return self:cursor_up()
  end, map_opts)
  vim.keymap.set('n', 'h', function()
    return self:cursor_left()
  end, map_opts)
  vim.keymap.set('n', 'l', function()
    return self:cursor_right()
  end, map_opts)
  vim.keymap.set('n', '<Down>', function()
    return self:cursor_down()
  end, map_opts)
  vim.keymap.set('n', '<Up>', function()
    return self:cursor_up()
  end, map_opts)
  vim.keymap.set('n', '<Left>', function()
    return self:cursor_left()
  end, map_opts)
  vim.keymap.set('n', '0', function()
    return self:beginning()
  end, map_opts)
  vim.keymap.set('n', '$', function()
    return self:ending()
  end, map_opts)
  vim.keymap.set('n', '<Right>', function()
    return self:cursor_right()
  end, map_opts)
  vim.keymap.set('n', '>', function()
    return self:forward()
  end, map_opts)
  vim.keymap.set('n', '<', function()
    return self:backward()
  end, map_opts)
  vim.keymap.set('n', '<CR>', function()
    return self:select()
  end, map_opts)
  vim.keymap.set('n', '.', function()
    return self:reset()
  end, map_opts)
  vim.keymap.set('n', 'i', function()
    return self:read_date()
  end, map_opts)
  vim.keymap.set('n', 'q', ':call nvim_win_close(win_getid(), v:true)<CR>', map_opts)
  vim.keymap.set('n', '<Esc>', ':call nvim_win_close(win_getid(), v:true)<CR>', map_opts)
  if self.clearable then
    vim.keymap.set('n', 'r', function()
      return self:clear_date()
    end, map_opts)
  end
  vim.keymap.set('n', 't', function()
    self:set_time()
  end, map_opts)
  vim.keymap.set('n', 'T', function()
    self:clear_time()
  end, map_opts)
  vim.keymap.set('n', 'd', function()
    self:set_day()
  end, map_opts)
  self:jump_day()
  return Promise.new(function(resolve)
    self.callback = resolve
  end)
end

function Calendar:render()
  vim.api.nvim_set_option_value('modifiable', true, { buf = self.buf })

  local cal_rows = { {}, {}, {}, {}, {}, {} } -- the calendar rows
  local start_from_sunday = config.calendar_week_start_day == 0
  local weekday_row = { 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' }

  if start_from_sunday then
    weekday_row = { 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' }
  end

  -- construct title (Month YYYY)
  local title = self.date:format('%B %Y')
  title = string.rep(' ', math.floor((width - title:len()) / 2)) .. title

  -- insert whitespace before first day of month
  local first_of_month = self.date:start_of('month')

  local end_of_month = self.date:end_of('month')
  local start_weekday = first_of_month:get_isoweekday()
  if start_from_sunday then
    start_weekday = first_of_month:get_weekday()
  end

  while start_weekday > 1 do
    table.insert(cal_rows[1], '  ')
    start_weekday = start_weekday - 1
  end

  -- insert dates into cal_rows
  local dates = first_of_month:get_range_until(end_of_month)
  local current_row = 1
  for _, day in ipairs(dates) do
    table.insert(cal_rows[current_row], day:format('%d'))
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

  table.insert(content, self:render_time())
  table.insert(content, '')

  -- TODO: redundant, since it's static data
  table.insert(content, ' [<] - prev month  [>] - next month')
  table.insert(content, ' [.] - today   [Enter] - select day')
  if self.clearable then
    table.insert(content, ' [i] - enter date  [r] - clear date')
  else
    table.insert(content, ' [i] - enter date')
  end

  if self:has_time() or self:_time_picker_active() then
    if not self:_time_picker_active() then
      table.insert(content, ' [t] - enter time  [T] - clear time')
    else
      table.insert(content, ' [d] - select day  [T] - clear time')
    end
  else
    table.insert(content, ' [t] - enter time')
  end

  vim.api.nvim_buf_set_lines(self.buf, 0, -1, true, content)
  vim.api.nvim_buf_clear_namespace(self.buf, namespace, 0, -1)
  if self.clearable then
    local range = Range:new({
      start_line = #content - 2,
      start_col = 0,
      end_line = #content - 2,
      end_col = 1,
    })
    colors.highlight({
      range = range,
      hlgroup = 'Comment',
    }, self.buf)
    self:_apply_hl('Comment', #content - 3, 0, -1)
  end

  if not self:has_time() then
    self:_apply_hl('Comment', 8, 0, -1)
  end

  self:_apply_hl('Comment', #content - 4, 0, -1)
  self:_apply_hl('Comment', #content - 3, 0, -1)
  self:_apply_hl('Comment', #content - 2, 0, -1)
  self:_apply_hl('Comment', #content - 1, 0, -1)

  for i, line in ipairs(content) do
    local from = 0
    local to, num

    while true do
      from, to, num = line:find('%s(%d%d?)%s', from + 1)
      if from == nil then
        break
      end
      if from and to then
        local day = self.date:set({ day = num })
        self:on_render_day(day, {
          from = from,
          to = to,
          line = i,
        })
      end
    end
  end

  vim.api.nvim_set_option_value('modifiable', false, { buf = self.buf })
end

function Calendar:_apply_hl(hl_group, start_line, start_col, end_col)
  local range = Range:new({
    start_line = start_line + 1,
    start_col = start_col + 1,
    end_line = start_line + 1,
    end_col = end_col > 0 and end_col + 1 or end_col,
  })
  colors.highlight({
    namespace = namespace,
    range = range,
    hlgroup = hl_group,
  }, self.buf)
end

---@param day OrgDate
---@param opts { from: number, to: number, line: number}
function Calendar:on_render_day(day, opts)
  if day:is_today() then
    self:_apply_hl('OrgCalendarToday', opts.line - 1, opts.from - 1, opts.to)
  end
  if day:is_same_day(self.date) then
    self:_apply_hl('OrgCalendarSelected', opts.line - 1, opts.from - 1, opts.to)
  end
  if self.on_day then
    self.on_day(
      day,
      vim.tbl_extend('force', opts, {
        buf = self.buf,
        namespace = namespace,
      })
    )
  end

  vim.api.nvim_set_option_value('modifiable', false, { buf = self.buf })
end

function Calendar.left_pad(time_part)
  return time_part < 10 and '0' .. time_part or time_part
end

function Calendar:render_time()
  local l_pad = '               '
  local r_pad = '              '
  local hour_str = self:has_time() and Calendar.left_pad(self.date.hour) or '--'
  local min_str = self:has_time() and Calendar.left_pad(self.date.min) or '--'
  return l_pad .. hour_str .. ':' .. min_str .. r_pad
end

function Calendar:rerender_time()
  vim.api.nvim_set_option_value('modifiable', true, { buf = self.buf })
  vim.api.nvim_buf_set_lines(self.buf, 8, 9, true, { self:render_time() })
  if self:has_time() then
    if self:_time_picker_active() then
      vim.api.nvim_buf_set_lines(self.buf, 13, 14, true, { ' [d] - select day  [T] - clear time' })
    else
      vim.api.nvim_buf_set_lines(self.buf, 13, 14, true, { ' [t] - enter time  [T] - clear time' })
    end
    self:_apply_hl('Normal', 8, 0, -1)
    self:_apply_hl('Comment', 13, 0, -1)
  else
    vim.api.nvim_buf_set_lines(self.buf, 13, 14, true, { ' [t] - enter time' })
    self:_apply_hl('Comment', 8, 0, -1)
    self:_apply_hl('Comment', 13, 0, -1)
  end
  vim.api.nvim_set_option_value('modifiable', false, { buf = self.buf })
end

function Calendar:has_time()
  return not self.date.date_only
end

---@private
function Calendar:_ensure_day()
  if self:_time_picker_active() then
    self:set_day()
  end
end

function Calendar:forward()
  self:_ensure_day()
  self.date = self.date:set({ day = 1 }):add({ month = vim.v.count1 })
  self:render()
  vim.fn.cursor(2, 1)
  vim.fn.search('01')
  self:render()
end

function Calendar:backward()
  self:_ensure_day()
  self.date = self.date:set({ day = 1 }):subtract({ month = vim.v.count1 }):last_day_of_month()
  self:render()
  vim.fn.cursor(8, 0)
  vim.fn.search([[\d\d]], 'b')
  self:render()
end

function Calendar:cursor_right()
  if self:_time_picker_active() then
    if self.select_state == SelState.HOUR then
      self:set_min_big()
    elseif self.select_state == SelState.MIN_BIG then
      self:set_min_small()
    elseif self.select_state == SelState.MIN_SMALL then
      self:set_sel_hour()
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
  self.date = self:get_selected_date()
  self:render()
end

function Calendar:cursor_left()
  if self:_time_picker_active() then
    if self.select_state == SelState.HOUR then
      self:set_min_small()
    elseif self.select_state == SelState.MIN_BIG then
      self:set_sel_hour()
    elseif self.select_state == SelState.MIN_SMALL then
      self:set_min_big()
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
  self.date = self:get_selected_date()
  self:render()
end

function Calendar:beginning()
  if self:_time_picker_active() then
    return
  end
  local line = vim.fn.line('.')
  vim.fn.cursor(line, vim.fn.getline('.'):match('^%s*'):len() + 1)
  self.date = self:get_selected_date()
  self:render()
end

function Calendar:ending()
  if self:_time_picker_active() then
    return
  end
  local line = vim.fn.line('.')
  local line_no_trailing_space = vim.fn.getline('.'):gsub('%s*$', '')
  vim.fn.cursor(line, line_no_trailing_space:len())
  self.date = self:get_selected_date()
  self:render()
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
--- by the user, so adjusting the hours would just move the time 1 hour back or forth
---@param direction string
---@param current OrgDate
---@param count number
---@return table
local function step_hour(direction, current, count)
  if not config.calendar.round_min_with_hours or current.min % big_minute_step == 0 then
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

function Calendar:cursor_up()
  if self:_time_picker_active() then
    -- to avoid unexpectedly changing the day we cache it ...
    local day = self.date.day
    if self.select_state == SelState.HOUR then
      self.date = self.date:add(step_hour('up', self.date, vim.v.count1))
    elseif self.select_state == SelState.MIN_BIG then
      self.date = self.date:add({ min = step_minute('up', big_minute_step, self.date.min, vim.v.count1) })
    elseif self.select_state == SelState.MIN_SMALL then
      self.date = self.date:add({ min = step_minute('up', small_minute_step, self.date.min, vim.v.count1) })
    end
    -- and restore the cached day after adjusting the time
    self.date = self.date:set({ day = day })
    self:rerender_time()
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
  self.date = self:get_selected_date()
  self:render()
end

function Calendar:cursor_down()
  if self:_time_picker_active() then
    local day = self.date.day
    if self.select_state == SelState.HOUR then
      self.date = self.date:subtract(step_hour('down', self.date, vim.v.count1))
    elseif self.select_state == SelState.MIN_BIG then
      self.date = self.date:subtract({ min = step_minute('down', big_minute_step, self.date.min, vim.v.count1) })
    elseif self.select_state == SelState.MIN_SMALL then
      self.date = self.date:subtract({ min = step_minute('down', small_minute_step, self.date.min, vim.v.count1) })
    end
    -- and restore the cached day after adjusting the time
    self.date = self.date:set({ day = day })
    self:rerender_time()
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
  self.date = self:get_selected_date()
  self:render()
end

function Calendar:reset()
  self:_ensure_day()
  self.date = self.date:set_todays_date()
  self:render()
  vim.fn.cursor(2, 1)
  vim.fn.search(self.date:format('%d'), 'W')
end

---@return OrgDate?
function Calendar:get_selected_date()
  if self:_time_picker_active() then
    return self.date
  end
  local col = vim.fn.col('.')
  local char = vim.fn.getline('.'):sub(col, col)
  local day = tonumber(vim.trim(vim.fn.expand('<cword>')))
  local line = vim.fn.line('.')
  vim.cmd([[redraw!]])
  if line < 3 or not char:match('%d') then
    utils.notify('Please select valid day number.', {
      level = 'warn',
    })
    return self.date
  end
  return self.date:set({
    day = day,
    date_only = self.date.date_only,
  })
end

function Calendar:select()
  local selected_date
  if not self:_time_picker_active() then
    selected_date = self:get_selected_date()
  else
    selected_date = self.date:set({
      day = self.date.day,
      hour = self.date.hour,
      min = self.date.min,
      date_only = false,
    })
    self.select_state = SelState.DAY
  end
  local cb = self.callback
  self.callback = nil

  vim.cmd([[echon]])
  vim.api.nvim_win_close(0, true)
  vim.api.nvim_set_current_win(self.prev_win)
  return cb(selected_date)
end

function Calendar:dispose()
  self.win = nil
  self.buf = nil
  if self.callback then
    self.callback(nil)
    vim.api.nvim_set_current_win(self.prev_win)
    self.callback = nil
  end
end

function Calendar:clear_date()
  local cb = self.callback
  self.callback = nil
  vim.cmd([[echon]])
  vim.api.nvim_win_close(0, true)
  vim.api.nvim_set_current_win(self.prev_win)
  cb(nil, true)
end

function Calendar:read_date()
  self:_ensure_day()
  local current_date = self:get_selected_date() or Date.today()
  Input.open('Enter date: ', current_date:to_string()):next(function(result)
    if result then
      local date = current_date:set_from_string(result)
      if not date then
        date = current_date:adjust(result)
      end

      self.date = date
      self:render()
      vim.fn.cursor(2, 1)
      vim.fn.search(date:format('%d'), 'W')
    end
  end)
end

function Calendar:set_time()
  self.date = self:get_selected_date()
  if self.date.date_only then
    self.date = self.date:set({ date_only = false }):set_current_time()
  end
  self:set_sel_hour()
  self:render() -- because we want to highlight the currently selected date, we have to render everything
end

function Calendar:set_day()
  if not self:_time_picker_active() then
    return
  end
  self:set_sel_day()
  self:rerender_time()
end

function Calendar:clear_time()
  if not self:has_time() then
    return
  end
  self.date = self.date:set({ hour = 0, min = 0, date_only = true })
  self:set_sel_day()
  self:rerender_time()
end

function Calendar:set_sel_hour()
  self.select_state = SelState.HOUR
  vim.fn.cursor({ 9, 16 })
end

function Calendar:set_sel_day()
  self.select_state = SelState.DAY
  self:jump_day()
end

function Calendar:set_min_big()
  self.select_state = SelState.MIN_BIG
  vim.fn.cursor({ 9, 19 })
end

function Calendar:set_min_small()
  self.select_state = SelState.MIN_SMALL
  vim.fn.cursor({ 9, 20 })
end

function Calendar:jump_day()
  local search_day = (self.date or Date.today()):format('%d')
  vim.fn.cursor(2, 1)
  vim.fn.search(search_day, 'W')
end

function Calendar:_time_picker_active()
  return self.select_state ~= SelState.DAY
end

return Calendar

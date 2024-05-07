local Date = require('orgmode.objects.date')
local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')
local config = require('orgmode.config')
local namespace = vim.api.nvim_create_namespace('org_calendar')

---@alias OrgCalendarOnRenderDayOpts { line: number, from: number, to: number, buf: number, namespace: number }
---@alias OrgCalendarOnRenderDay fun(day: OrgDate, opts: OrgCalendarOnRenderDayOpts)

---@class OrgCalendar
---@field win number
---@field buf number
---@field callback fun(date: OrgDate | nil, cleared?: boolean)
---@field namespace function
---@field date OrgDate
---@field month OrgDate
---@field title? string
---@field on_day? OrgCalendarOnRenderDay

local Calendar = {
  win = nil,
  buf = nil,
  date = nil,
  clearable = false,
}
Calendar.__index = Calendar

vim.cmd([[hi default OrgCalendarToday gui=reverse cterm=reverse]])

---@param data { date?: OrgDate, clearable?: boolean, title?: string, on_day?: OrgCalendarOnRenderDay }
function Calendar.new(data)
  data = data or {}
  local this = setmetatable({}, Calendar)
  this.clearable = data.clearable
  this.title = data.title
  this.on_day = data.on_day
  if data.date then
    this.date = data.date
    this.month = this.date:set({ day = 1 })
  else
    this.month = Date.today():start_of('month')
  end
  return this
end

local width = 36
local height = 10
local x_offset = 1 -- one border cell
local y_offset = 2 -- one border cell and one padding cell

---@return OrgPromise<OrgDate | nil>
function Calendar:open()
  local opts = {
    relative = 'editor',
    width = width,
    height = self.clearable and height + 1 or height,
    style = 'minimal',
    border = config.win_border,
    row = vim.o.lines / 2 - (y_offset + height) / 2,
    col = vim.o.columns / 2 - (x_offset + width) / 2,
    title = self.title or 'Calendar',
    title_pos = 'center',
  }

  self.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(self.buf, 'orgcalendar')
  self.win = vim.api.nvim_open_win(self.buf, true, opts)

  local calendar_augroup = vim.api.nvim_create_augroup('org_calendar', { clear = true })
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = self.buf,
    group = calendar_augroup,
    callback = function()
      self:dispose()
    end,
    once = true,
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
  local search_day = Date.today():format('%d')
  if self.date then
    search_day = self.date:format('%d')
  end
  vim.fn.cursor(2, 1)
  vim.fn.search(search_day, 'W')
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
  local title = self.month:format('%B %Y')
  title = string.rep(' ', math.floor((width - title:len()) / 2)) .. title

  -- insert whitespace before first day of month
  local start_weekday = self.month:get_isoweekday()
  if start_from_sunday then
    start_weekday = self.month:get_weekday()
  end
  while start_weekday > 1 do
    table.insert(cal_rows[1], '  ')
    start_weekday = start_weekday - 1
  end

  -- insert dates into cal_rows
  local dates = self.month:get_range_until(self.month:end_of('month'))
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
  -- TODO: redundant, since it's static data
  table.insert(content, ' [<] - prev month  [>] - next month')
  table.insert(content, ' [.] - today   [Enter] - select day')
  if self.clearable then
    table.insert(content, ' [i] - enter date  [r] - clear date')
  else
    table.insert(content, ' [i] - enter date')
  end

  vim.api.nvim_buf_set_lines(self.buf, 0, -1, true, content)
  vim.api.nvim_buf_clear_namespace(self.buf, namespace, 0, -1)
  if self.clearable then
    vim.api.nvim_buf_add_highlight(self.buf, namespace, 'Comment', #content - 3, 0, -1)
  end
  vim.api.nvim_buf_add_highlight(self.buf, namespace, 'Comment', #content - 2, 0, -1)
  vim.api.nvim_buf_add_highlight(self.buf, namespace, 'Comment', #content - 1, 0, -1)

  for i, line in ipairs(content) do
    local from = 0
    local to, num

    while true do
      from, to, num = line:find('%s(%d%d?)%s', from + 1)
      if from == nil then
        break
      end
      if from and to then
        local date = self.month:set({ day = num })
        self:on_render_day(date, {
          from = from,
          to = to,
          line = i,
        })
      end
    end
  end

  vim.api.nvim_set_option_value('modifiable', false, { buf = self.buf })
end

---@param day OrgDate
---@param opts { from: number, to: number, line: number}
function Calendar:on_render_day(day, opts)
  local is_today = day:is_today()
  if is_today then
    vim.api.nvim_buf_add_highlight(self.buf, namespace, 'OrgCalendarToday', opts.line - 1, opts.from - 1, opts.to)
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
end

function Calendar:forward()
  self.month = self.month:add({ month = vim.v.count1 })
  self:render()
  vim.fn.cursor(2, 1)
  vim.fn.search('01')
end

function Calendar:backward()
  self.month = self.month:subtract({ month = vim.v.count1 })
  self:render()
  vim.fn.cursor(vim.fn.line('$'), 0)
  vim.fn.search([[\d\d]], 'b')
end

function Calendar:cursor_right()
  for i = 1, vim.v.count1 do
    local line, col = vim.fn.line('.'), vim.fn.col('.')
    local curr_line = vim.fn.getline('.')
    local offset = curr_line:sub(col + 1, #curr_line):find('%d%d')
    if offset ~= nil then
      vim.fn.cursor(line, col + offset)
    end
  end
end

function Calendar:cursor_left()
  for i = 1, vim.v.count1 do
    local line, col = vim.fn.line('.'), vim.fn.col('.')
    local curr_line = vim.fn.getline('.')
    local _, offset = curr_line:sub(1, col - 1):find('.*%d%d')
    if offset ~= nil then
      vim.fn.cursor(line, offset)
    end
  end
end

function Calendar:cursor_up()
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

function Calendar:cursor_down()
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

function Calendar:reset()
  local today = self.month:set_todays_date()
  self.month = today:set({ day = 1 })
  self:render()
  vim.fn.cursor(2, 1)
  vim.fn.search(today:format('%d'), 'W')
end

function Calendar:get_selected_date()
  local col = vim.fn.col('.')
  local char = vim.fn.getline('.'):sub(col, col)
  local day = vim.trim(vim.fn.expand('<cword>'))
  local line = vim.fn.line('.')
  vim.cmd([[redraw!]])
  if line < 3 or not char:match('%d') then
    return utils.echo_warning('Please select valid day number.', nil, false)
  end
  return self.month:set({ day = tonumber(day) })
end

function Calendar:select()
  local selected_date = self:get_selected_date()
  local cb = self.callback
  self.callback = nil
  vim.cmd([[echon]])
  vim.api.nvim_win_close(0, true)
  return cb(selected_date)
end

function Calendar:dispose()
  self.win = nil
  self.buf = nil
  self.month = Date.today():start_of('month')
  if self.callback then
    self.callback(nil)
    self.callback = nil
  end
end

function Calendar:clear_date()
  local cb = self.callback
  self.callback = nil
  vim.cmd([[echon]])
  vim.api.nvim_win_close(0, true)
  cb(nil, true)
end

function Calendar:read_date()
  vim.ui.input({ prompt = 'Enter date: ' }, function(result)
    if result then
      local date = Date.from_string(result)
      if not date then
        date = self:get_selected_date():adjust(result)
      end

      self.date = date
      self.month = date:set({ day = 1 })
      self:render()
      vim.fn.cursor(2, 1)
      vim.fn.search(date:format('%d'), 'W')
    end
  end)
end

return Calendar

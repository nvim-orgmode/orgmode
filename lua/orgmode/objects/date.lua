-- TODO
-- Support diary format and format without short date name
---@type table<string, OrgDateSpan>
local spans = { d = 'day', m = 'month', y = 'year', h = 'hour', w = 'week', M = 'min' }
local config = require('orgmode.config')
local utils = require('orgmode.utils')
local Range = require('orgmode.files.elements.range')
local pattern = '([<%[])(%d%d%d%d%-%d?%d%-%d%d[^>%]]*)([>%]])'
local date_format = '%Y-%m-%d'
local time_format = '%H:%M'

---@alias OrgDateSpan 'minute' | 'hour' | 'day' | 'week' | 'month' | 'year'

---@class OrgDate
---@field type string
---@field active boolean
---@field date_only boolean
---@field range OrgRange
---@field day number
---@field month number
---@field year number
---@field hour number
---@field min number
---@field timestamp number
---@field timestamp_end number
---@field is_dst boolean
---@field is_date_range_start boolean
---@field is_date_range_end boolean
---@field related_date_range OrgDate
---@field dayname string
---@field adjustments string[]
local Date = {
  ---@type fun(this: OrgDate, other: OrgDate): boolean
  __eq = function(this, other)
    return this.timestamp == other.timestamp
  end,
  ---@type fun(this: OrgDate, other: OrgDate): boolean
  __lt = function(this, other)
    return this.timestamp < other.timestamp
  end,
  ---@type fun(this: OrgDate, other: OrgDate): boolean
  __le = function(this, other)
    return this.timestamp <= other.timestamp
  end,
  ---@type fun(this: OrgDate, other: OrgDate): boolean
  __gt = function(this, other)
    return this.timestamp > other.timestamp
  end,
  ---@type fun(this: OrgDate, other: OrgDate): boolean
  __ge = function(this, other)
    return this.timestamp >= other.timestamp
  end,
}

---@param source table
---@param target? table
---@param include_sec? boolean
---@return table
local function set_date_opts(source, target, include_sec)
  target = target or {}
  for _, field in ipairs({ 'year', 'month', 'day' }) do
    target[field] = source[field]
  end
  for _, field in ipairs({ 'hour', 'min' }) do
    target[field] = source[field] or 0
  end
  if include_sec then
    target.sec = source.sec or 0
  end
  return target
end

---@param data table
function Date:new(data)
  data = data or {}
  local date_only = data.date_only or (not data.hour and not data.min)
  local opts = set_date_opts(data)
  opts.type = data.type or 'NONE'
  opts.active = data.active or false
  opts.range = data.range
  opts.timestamp = os.time(opts)
  opts.date_only = date_only
  opts.dayname = os.date('%a', opts.timestamp)
  opts.is_dst = os.date('*t', opts.timestamp).isdst
  opts.adjustments = data.adjustments or {}
  opts.timestamp_end = data.timestamp_end
  opts.is_date_range_start = data.is_date_range_start or false
  opts.is_date_range_end = data.is_date_range_end or false
  opts.related_date_range = data.related_date_range or nil
  setmetatable(opts, self)
  self.__index = self
  return opts
end

---@param time table
---@return OrgDate
function Date:from_time_table(time)
  local range_diff = self.timestamp_end and self.timestamp_end - self.timestamp or 0
  local timestamp = os.time(set_date_opts(time, {}, true))
  local opts = set_date_opts(os.date('*t', timestamp))
  opts.date_only = self.date_only
  opts.dayname = self.dayname
  opts.adjustments = self.adjustments
  opts.type = self.type
  opts.active = self.active
  opts.range = self.range
  if self.timestamp_end then
    opts.timestamp_end = timestamp + range_diff
  end
  opts.is_date_range_start = self.is_date_range_start
  opts.is_date_range_end = self.is_date_range_end
  opts.related_date_range = self.related_date_range
  return Date:new(opts)
end

---@param opts? table
---@return OrgDate
function Date:set(opts)
  opts = opts or {}
  local date = os.date('*t', self.timestamp)
  for opt, val in pairs(opts) do
    date[opt] = val
  end
  return self:from_time_table(date)
end

---@param opts? table
---@return OrgDate
function Date:clone(opts)
  local date = Date:new(self)
  for opt, val in pairs(opts or {}) do
    date[opt] = val
  end
  return date
end

---@param date string
---@param dayname string
---@param time string
---@param adjustments string
---@param data table
---@return OrgDate
local function parse_datetime(date, dayname, time, time_end, adjustments, data)
  local date_parts = vim.split(date, '-')
  local time_parts = vim.split(time, ':')
  local opts = {
    year = tonumber(date_parts[1]),
    month = tonumber(date_parts[2]),
    day = tonumber(date_parts[3]),
    hour = tonumber(time_parts[1]),
    min = tonumber(time_parts[2]),
  }
  opts.dayname = dayname
  opts.adjustments = adjustments
  if time_end then
    local time_end_parts = vim.split(time_end, ':')
    opts.timestamp_end = os.time({
      year = tonumber(date_parts[1]),
      month = tonumber(date_parts[2]),
      day = tonumber(date_parts[3]),
      hour = tonumber(time_end_parts[1]),
      min = tonumber(time_end_parts[2]),
    })
  end
  opts = vim.tbl_extend('force', opts, data or {})
  return Date:new(opts)
end

---@param date string
---@param dayname string
---@param adjustments string
---@param data table
---@return OrgDate
local function parse_date(date, dayname, adjustments, data)
  local date_parts = vim.split(date, '-')
  local opts = {
    year = tonumber(date_parts[1]),
    month = tonumber(date_parts[2]),
    day = tonumber(date_parts[3]),
  }
  opts.adjustments = adjustments
  opts.dayname = dayname
  opts = vim.tbl_extend('force', opts, data or {})
  return Date:new(opts)
end

---@param data? table
---@return OrgDate
local function today(data)
  local date = os.date('*t', os.time()) --[[@as osdate]]
  local opts = vim.tbl_deep_extend('force', date, data or {})
  opts.date_only = true
  return Date:new(opts)
end

---@return OrgDate
local function tomorrow()
  local today_date = today()
  return today_date:adjust('+1d')
end

---@param data? table
---@return OrgDate
local function now(data)
  local date = os.date('*t', os.time()) --[[@as osdate]]
  local opts = vim.tbl_deep_extend('force', date, data or {})
  return Date:new(opts)
end

---@param datestr string
---@return string|nil
local function is_valid_date(datestr)
  return datestr:match('^%d%d%d%d%-%d%d%-%d%d%s+') or datestr:match('^%d%d%d%d%-%d%d%-%d%d$')
end

---@param datestr string
---@param opts? table
---@return OrgDate
local function from_string(datestr, opts)
  if not is_valid_date(datestr) then
    return nil
  end
  local parts = vim.split(datestr, '%s+')
  local date = table.remove(parts, 1)
  local dayname = nil
  local time = nil
  local time_end = nil
  local adjustments = {}
  for _, part in ipairs(parts) do
    if part:match('%a%a%a') then
      dayname = part
    elseif part:match('%d?%d:%d%d%-%d?%d:%d%d') then
      local times = vim.split(part, '-')
      time = times[1]
      time_end = times[2]
    elseif part:match('%d?%d:%d%d') then
      time = part
    elseif part:match('[%.%+%-]+%d+[hdwmy]?') then
      table.insert(adjustments, part)
    end
  end

  if time then
    return parse_datetime(date, dayname, time, time_end, adjustments, opts)
  end

  return parse_date(date, dayname, adjustments, opts)
end

--- @param datestr string
--- @return table[]
local function parse_parts(datestr)
  local result = {}
  local counter = 1
  local patterns = {
    { type = 'date', rgx = '^%d%d%d%d%-%d%d%-%d%d$' },
    { type = 'dayname', rgx = '^%a%a%a$' },
    { type = 'time', rgx = '^%d?%d:%d%d$' },
    { type = 'time_range', rgx = '^%d?%d:%d%d%-%d?%d:%d%d$' },
    { type = 'adjustment', rgx = '^[%.%+%-]+%d+[hdwmy]?$' },
  }
  for space, item in string.gmatch(datestr, '(%s*)(%S+)') do
    local from = counter + space:len()
    for _, dt_pattern in ipairs(patterns) do
      if item:match(dt_pattern.rgx) then
        table.insert(result, {
          type = dt_pattern.type,
          value = item,
          from = from,
          to = from + item:len() - 1,
        })
        counter = counter + item:len() + space:len()
      end
    end
  end
  return result
end

local function from_org_date(datestr, opts)
  local from_open, from, from_close, delimiter, to_open, to, to_close = datestr:match(pattern .. '(%-%-)' .. pattern)
  if not delimiter then
    if not is_valid_date(datestr:sub(2, -2)) then
      return {}
    end
    local is_active = datestr:sub(1, 1) == '<' and datestr:sub(-1) == '>'
    local dateval = datestr:gsub('^[%[<]', ''):gsub('[%]>]', '')
    return { from_string(dateval, vim.tbl_extend('force', opts or {}, { active = is_active })) }
  end
  local line = opts.range.start_line
  local start_date = from_string(
    from,
    vim.tbl_extend('force', opts or {}, {
      active = from_open == '<' and from_close == '>',
      is_date_range_start = true,
      range = Range:new({
        start_line = line,
        end_line = line,
        start_col = opts.range.start_col,
        end_col = opts.range.start_col + (from_open .. from .. from_close):len() - 1,
      }),
    })
  )

  local end_date = from_string(
    to,
    vim.tbl_extend('force', opts or {}, {
      active = to_open == '<' and to_close == '>',
      is_date_range_end = true,
      range = Range:new({
        start_line = line,
        end_line = line,
        start_col = start_date.range.end_col + 3,
        end_col = opts.range.end_col,
      }),
      related_date_range = start_date,
    })
  )
  start_date.related_date_range = end_date

  return { start_date, end_date }
end

---@return string
function Date:to_string()
  local format = date_format
  if self.dayname then
    format = format .. ' %a'
  end

  local date = tostring(os.date(format, self.timestamp))

  if self:has_time() then
    date = date .. ' ' .. self:format_time()
  end

  if #self.adjustments > 0 then
    date = date .. ' ' .. table.concat(self.adjustments, ' ')
  end

  return date
end

---@param active boolean|nil
---@return string
function Date:to_wrapped_string(active)
  if type(active) ~= 'boolean' then
    active = self.active
  end
  local date = self:to_string()
  local open = active and '<' or '['
  local close = active and '>' or ']'
  return string.format('%s%s%s', open, date, close)
end

---@return string
function Date:format_time()
  if not self:has_time() then
    return ''
  end
  local t = self:format(time_format)
  if self.timestamp_end then
    t = t .. '-' .. os.date(time_format, self.timestamp_end)
  end
  return t
end

---@param value string
---@return OrgDate
function Date:adjust(value)
  local adjustment = self:_parse_adjustment(value)
  local modifier = { [adjustment.span] = adjustment.amount }
  if adjustment.is_negative then
    return self:subtract(modifier)
  end
  return self:add(modifier)
end

---@param value string
---@return OrgDate
function Date:adjust_end_time(value)
  if not self.timestamp_end then
    return self
  end
  local time_end = from_string(os.date(date_format .. ' ' .. time_format, self.timestamp_end))
  time_end = time_end:adjust(value)
  self.timestamp_end = time_end.timestamp
  return self
end

---@param value string
---@return table
function Date:_parse_adjustment(value)
  local operation, amount, span = value:match('^([%+%-])(%d+)([hdwmyM]?)')
  if not operation or not amount then
    return { span = 'day', amount = 0 }
  end
  if not span or span == '' then
    span = 'd'
  end
  return {
    span = spans[span],
    amount = tonumber(amount),
    is_negative = operation == '-',
  }
end

function Date:without_adjustments()
  return self:clone({ adjustments = {} })
end

---@param span OrgDateSpan
---@return OrgDate
function Date:start_of(span)
  if #span == 1 then
    span = spans[span]
  end
  local opts = {
    day = { hour = 0, min = 0 },
    month = { day = 1, hour = 0, min = 0 },
    year = { month = 1, day = 1, hour = 0, min = 0 },
    hour = { min = 0 },
    minute = { sec = 0 },
  }
  if opts[span] then
    return self:set(opts[span])
  end

  if span == 'week' then
    local this = self
    local date = os.date('*t', self.timestamp)
    while date.wday ~= config:get_week_start_day_number() do
      this = this:adjust('-1d')
      date = os.date('*t', this.timestamp)
    end
    return this:set(opts.day)
  end

  return self
end

---@param span string
---@return OrgDate
function Date:end_of(span)
  if #span == 1 then
    span = spans[span]
  end
  local opts = {
    day = { hour = 23, min = 59 },
    year = { month = 12, day = 31, hour = 23, min = 59 },
    hour = { min = 59 },
  }

  if opts[span] then
    return self:set(opts[span])
  end

  if span == 'week' then
    local this = self
    local date = os.date('*t', self.timestamp)
    while date.wday ~= config:get_week_end_day_number() do
      this = this:adjust('+1d')
      date = os.date('*t', this.timestamp)
    end
    return this:set(opts.day)
  end

  if span == 'month' then
    return self:add({ month = 1 }):start_of('month'):adjust('-1d'):end_of('day')
  end

  return self
end

---@return number
function Date:get_isoweekday()
  local date = os.date('*t', self.timestamp)
  return utils.convert_to_isoweekday(date.wday)
end

---@return number
function Date:get_weekday()
  local date = os.date('*t', self.timestamp)
  return date.wday
end

---@param isoweekday number
---@param future? boolean
---@return OrgDate
function Date:set_isoweekday(isoweekday, future)
  local current_isoweekday = self:get_isoweekday()
  if isoweekday <= current_isoweekday then
    return self:subtract({ day = current_isoweekday - isoweekday })
  end
  if future then
    return self:add({ day = isoweekday - current_isoweekday })
  end
  return self:subtract({ week = 1 }):add({ day = isoweekday - current_isoweekday })
end

---@param opts table
---@return OrgDate
function Date:add(opts)
  opts = opts or {}
  local date = os.date('*t', self.timestamp)
  for opt, val in pairs(opts) do
    if opt == 'week' then
      opt = 'day'
      val = val * 7
    end
    date[opt] = date[opt] + val
  end
  return self:from_time_table(date)
end

---@param opts table
---@return OrgDate
function Date:subtract(opts)
  opts = opts or {}
  for opt, val in pairs(opts) do
    opts[opt] = -val
  end
  return self:add(opts)
end

---@param date OrgDate
---@param span? string
---@return boolean
function Date:is_same(date, span)
  if not span then
    return self.timestamp == date.timestamp
  end
  return self:start_of(span).timestamp == date:start_of(span).timestamp
end

---@param from OrgDate
---@param to OrgDate
---@param span string
---@return boolean
function Date:is_between(from, to, span)
  local f = from
  local t = to
  if span then
    f = from:start_of(span)
    t = to:end_of(span)
  end
  return self.timestamp >= f.timestamp and self.timestamp <= t.timestamp
end

---@param date OrgDate
---@param span? string
---@return boolean
function Date:is_before(date, span)
  return not self:is_same_or_after(date, span)
end

---@param date OrgDate
---@param span string
---@return boolean
function Date:is_same_or_before(date, span)
  local d = date
  local s = self
  if span then
    d = date:start_of(span)
    s = self:start_of(span)
  end
  return s.timestamp <= d.timestamp
end

---@param date OrgDate
---@param span string
---@return boolean
function Date:is_after(date, span)
  return not self:is_same_or_before(date, span)
end

---@param date OrgDate
---@param span string
---@return boolean
function Date:is_same_or_after(date, span)
  local d = date
  local s = self
  if span then
    d = date:start_of(span)
    s = self:start_of(span)
  end
  return s.timestamp >= d.timestamp
end

---@return boolean
function Date:is_today()
  if self.is_today_date == nil then
    local date = now()
    self.is_today_date = date.year == self.year and date.month == self.month and date.day == self.day
  end
  return self.is_today_date
end

---@return boolean
function Date:is_obsolete_range_end()
  return self.is_date_range_end and self.related_date_range:is_same(self, 'day')
end

---@return boolean
function Date:has_date_range_end()
  return self.related_date_range and self.is_date_range_start
end

function Date:has_time()
  return not self.date_only
end

---@return boolean
function Date:has_time_range()
  return self.timestamp_end ~= nil
end

---@return OrgDate|nil
function Date:get_date_range_end()
  return self:has_date_range_end() and self.related_date_range or nil
end

---Return number of days for a date range
---@return number
function Date:get_date_range_days()
  if not self:is_none() or not self.related_date_range then
    return 0
  end
  return math.abs(self.related_date_range:diff(self)) + 1
end

---@param date OrgDate
---@return boolean
function Date:is_in_date_range(date)
  if self.is_date_range_start then
    local ranges_same_day = self.related_date_range:is_obsolete_range_end()
    if ranges_same_day then
      return false
    end
    return date:is_between(self, self.related_date_range:subtract({ day = 1 }), 'day')
  end
  return false
end

---@param date OrgDate
---@return OrgDate[]
function Date:get_range_until(date)
  local this = self
  local dates = {}
  while this.timestamp < date.timestamp do
    table.insert(dates, this)
    this = this:add({ day = 1 })
  end
  return dates
end

---@param format string
---@return string
function Date:format(format)
  return tostring(os.date(format, self.timestamp))
end

---@param from OrgDate
---@param span? 'day' | 'minute'
---@return number
function Date:diff(from, span)
  span = span or 'day'
  local to_date = self:start_of(span)
  local from_date = from:start_of(span)
  local diff = to_date.timestamp - from_date.timestamp
  if to_date.is_dst ~= from_date.is_dst then
    diff = diff + (to_date.is_dst and 3600 or -3600)
  end
  local durations = {
    day = 86400,
    minute = 60,
  }
  return math.floor(diff / durations[span])
end

---@param span string
---@return boolean
function Date:is_past(span)
  return self:is_before(now(), span)
end

---@param span string
---@return boolean
function Date:is_today_or_past(span)
  return self:is_same_or_before(now(), span)
end

---@param span string
---@return boolean
function Date:is_future(span)
  return self:is_after(now(), span)
end

---@param span string
---@return boolean
function Date:is_today_or_future(span)
  return self:is_same_or_after(now(), span)
end

---@param from OrgDate
---@return string
function Date:humanize(from)
  from = from or now()
  local diff = self:diff(from)
  if diff == 0 then
    return 'Today'
  end
  if diff < 0 then
    return math.abs(diff) .. ' d. ago'
  end
  return 'In ' .. diff .. ' d.'
end

---@return boolean
function Date:is_deadline()
  return self.active and self.type == 'DEADLINE'
end

---@return boolean
function Date:is_none()
  return self.active and self.type == 'NONE'
end

---@return boolean
function Date:is_logbook()
  return self.type == 'LOGBOOK'
end

---@return boolean
function Date:is_scheduled()
  return self.active and self.type == 'SCHEDULED'
end

---@return boolean
function Date:is_closed()
  return self.type == 'CLOSED'
end

function Date:is_planning_date()
  return self:is_deadline() or self:is_scheduled() or self:is_closed()
end

---@return boolean
function Date:is_weekend()
  local isoweekday = self:get_isoweekday()
  return isoweekday >= 6
end

---@return table|nil
function Date:get_negative_adjustment()
  if #self.adjustments == 0 then
    return nil
  end
  for _, adj in ipairs(self.adjustments) do
    if adj:match('^%-%d+') then
      return self:_parse_adjustment(adj)
    end
  end
  return nil
end

function Date:with_negative_adjustment()
  local adj = self:get_negative_adjustment()
  if not adj then
    return self
  end

  if self:is_deadline() then
    return self:subtract({ [adj.span] = adj.amount })
  end

  if self:is_scheduled() then
    return self:add({ [adj.span] = adj.amount })
  end

  return self
end

---Get repeater value (ex. +1w, .+1w, ++1w)
---@return string | nil
function Date:get_repeater()
  if #self.adjustments == 0 then
    return nil
  end

  for _, adj in ipairs(self.adjustments) do
    if adj:match('^[%+%.]?%+%d+') then
      return adj
    end
  end
  return nil
end

function Date:set_todays_date()
  local time = os.date('*t', os.time())
  return self:set({
    year = time.year,
    month = time.month,
    day = time.day,
  })
end

function Date:apply_repeater()
  local repeater = self:get_repeater()
  local date = self
  local current_time = now()
  if not repeater then
    return self
  end

  -- Repeater relative to completion time
  if repeater:match('^%.%+%d+') then
    -- Strip the '.' from the repeater
    local offset = repeater:sub(2)
    return date:set_todays_date():adjust(offset)
  end

  -- Repeater relative to deadline/scheduled date
  if repeater:match('^%+%+%d') then
    -- Strip the '+' from the repeater
    local offset = repeater:sub(2)
    repeat
      date = date:adjust(offset)
    until date.timestamp > current_time.timestamp
    return date
  end

  -- Simple repeat; apply repeater once to deadline/scheduled date
  return date:adjust(repeater)
end

---@param date OrgDate
---@return boolean
function Date:repeats_on(date)
  local repeater = self:get_repeater()
  if not repeater then
    return false
  end
  repeater = repeater:gsub('^%.', ''):gsub('^%+%+', '+')
  local repeat_date = self:start_of('day')
  local date_start = date:start_of('day')
  while repeat_date.timestamp < date_start.timestamp do
    repeat_date = repeat_date:adjust(repeater)
  end
  return repeat_date:is_same(date, 'day')
end

---@param date OrgDate
function Date:apply_repeater_until(date)
  local repeater = self:get_repeater()
  if not repeater then
    return self
  end

  repeater = repeater:gsub('^%.', ''):gsub('^%+%+', '+')
  local repeat_date = self

  while repeat_date.timestamp < date.timestamp do
    repeat_date = repeat_date:adjust(repeater)
  end

  return repeat_date
end

---@return OrgDate
function Date:get_adjusted_date()
  if not self:is_deadline() and not self:is_scheduled() then
    return self
  end

  local adj = self:get_negative_adjustment()

  if self:is_deadline() then
    local warning_amount = config.org_deadline_warning_days
    local span = 'day'
    if adj then
      warning_amount = adj.amount
      span = adj.span
    end
    return self:subtract({ [span] = warning_amount })
  end

  if not adj then
    return self
  end
  return self:add({ [adj.span] = adj.amount })
end

---@return string
function Date:get_week_number()
  return self:format('%V')
end

---@param line string
---@param lnum number
---@param open string
---@param datetime string
---@param close string
---@param last_match? OrgDate
---@param type? string
---@return OrgDate
local function from_match(line, lnum, open, datetime, close, last_match, type)
  local search_from = last_match ~= nil and last_match.range.end_col or 0
  local from, to = line:find(vim.pesc(open .. datetime .. close), search_from)
  local is_date_range_end = last_match and last_match.is_date_range_start and line:sub(from - 2, from - 1) == '--'
  local opts = {
    type = type,
    active = open == '<',
    range = Range:new({ start_line = lnum, end_line = lnum, start_col = from, end_col = to }),
    is_date_range_start = line:sub(to + 1, to + 2) == '--',
  }
  local parsed_date = from_string(vim.trim(datetime), opts)
  if is_date_range_end then
    parsed_date.is_date_range_end = true
    parsed_date.related_date_range = last_match
    last_match.related_date_range = parsed_date
  end

  return parsed_date
end

---@param line string
---@param lnum number
---@return OrgDate[]
local function parse_all_from_line(line, lnum)
  local is_comment = line:match('^%s*#[^%+]')
  if is_comment then
    return {}
  end
  local dates = {}
  for open, datetime, close in line:gmatch(pattern) do
    local parsed_date = from_match(line, lnum, open, datetime, close, dates[#dates])
    if parsed_date then
      table.insert(dates, parsed_date)
    end
  end
  return dates
end

---@param value any
local function is_date_instance(value)
  return getmetatable(value) == Date
end

---@param opts { year: number, month?: number, day?: number, hour?: number, min?: number, sec?: number }
---@return OrgDate
local function from_table(opts)
  return Date:from_time_table({
    year = opts.year,
    month = opts.month or 1,
    day = opts.day or 1,
    hour = opts.hour or 0,
    min = opts.min or 0,
    sec = opts.sec or 0,
  })
end
return {
  parse_parts = parse_parts,
  from_org_date = from_org_date,
  from_string = from_string,
  from_table = from_table,
  now = now,
  today = today,
  tomorrow = tomorrow,
  parse_all_from_line = parse_all_from_line,
  is_valid_date = is_valid_date,
  is_date_instance = is_date_instance,
  from_match = from_match,
  pattern = pattern,
}

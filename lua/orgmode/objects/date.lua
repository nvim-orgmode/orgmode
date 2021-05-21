local Date = {}
local spans = { d = 'day', m = 'month', y = 'year', h = 'hour', w = 'week' }
local config = require('orgmode.config')
local utils = require('orgmode.utils')
local pattern = '([<%[])(%d%d%d%d%-%d?%d%-%d%d[^>%]]*)([>%]])'

---@param source table
---@param target table
---@return table
local function set_date_opts(source, target)
  target = target or {}
  for _, field in ipairs({'year', 'month', 'day'}) do
    target[field] = source[field]
  end
  for _, field in ipairs({'hour', 'min'}) do
    target[field] = source[field] or 0
  end
  return target
end

-- TODO: Support diary format and format without short date name
---@class Date
---@param data table
function Date:new(data)
  data = data or {}
  local date_only = data.date_only or (not data.hour and not data.min)
  local opts = set_date_opts(data)
  opts.type = data.type or 'NONE'
  opts.active = data.active or false
  opts.range = data.range
  if opts.year and opts.month and opts.day then
    opts.timestamp = os.time(opts)
  else
    opts.timestamp = os.time()
    local date = os.date('*t', opts.timestamp)
    opts = set_date_opts(date, opts)
  end
  opts.date_only = date_only
  opts.dayname = data.dayname
  opts.adjustments = data.adjustments or {}
  setmetatable(opts, self)
  self.__index = self
  return opts
end

---@param time table
---@return Date
function Date:from_time_table(time)
  local timestamp = os.time(set_date_opts(time))
  local opts = set_date_opts(os.date('*t', timestamp))
  opts.date_only = self.date_only
  opts.dayname = self.dayname
  opts.adjustments = self.adjustments
  opts.type = self.type
  opts.active = self.active
  opts.range = self.range
  return Date:new(opts)
end

---@param opts table
---@return Date
function Date:set(opts)
  opts = opts or {}
  local date = os.date('*t', self.timestamp)
  for opt, val in pairs(opts) do
    date[opt] = val
  end
  return self:from_time_table(date)
end

---@param opts table
---@return Date
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
---@return Date
local function parse_datetime(date, dayname, time, adjustments, data)
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
  opts = vim.tbl_extend('force', opts, data or {})
  return Date:new(opts)
end

---@param date string
---@param dayname string
---@param adjustments string
---@param data table
---@return Date
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

---@param datestr string
---@param opts table
---@return Date
local function from_string(datestr, opts)
  if not datestr:match('^%d%d%d%d%-%d%d%-%d%d$') and not datestr:match('^%d%d%d%d%-%d%d%-%d%d%s+') then
    return Date:new(opts)
  end
  local parts = vim.split(datestr, '%s+')
  local date = table.remove(parts, 1)
  local dayname = nil
  local time = nil
  local adjustments = {}
  for _, part in ipairs(parts) do
    if part:match('%a%a%a') then
      dayname = part
    elseif part:match('%d?%d:%d%d') then
      time = part
    elseif part:match('[%.%+%-]+%d+[hdwmy]?') then
      table.insert(adjustments, part)
    end
  end

  if time then
    return parse_datetime(date, dayname, time, adjustments, opts)
  end

  return parse_date(date, dayname, adjustments, opts)
end

---@return Date
local function now()
  return Date:new()
end

---@return string
function Date:to_string()
  local date = ''
  local format = '%Y-%m-%d'
  if self.dayname then
    format = format..' %a'
  end

  if self.date_only then
    date = os.date(format, self.timestamp)
  else
    date = os.date(format..' %H:%M', self.timestamp)
  end

  if #self.adjustments > 0 then
    date = date..' '..table.concat(self.adjustments, ' ')
  end

  return date
end

function Date:format_time()
  if self.date_only then return '' end
  return self:format('%H:%M')
end

---@param value string
---@return string
function Date:adjust(value)
  local adjustment = self:_parse_adjustment(value)
  local modifier = { [adjustment.span] = adjustment.amount }
  if adjustment.is_negative then
    return self:subtract(modifier)
  end
  return self:add(modifier)
end

---@param value string
---@return table
function Date:_parse_adjustment(value)
  local operation, amount, span = value:match('^([%+%-])(%d+)([hdwmy]?)')
  if not operation or not amount then
    return { span = 'day', amount = 0 }
  end
  if not span or span == '' then
    span = 'd'
  end
  return {
    span = spans[span],
    amount = tonumber(amount),
    is_negative = operation == '-'
  }
end

---@param span string
---@return Date
function Date:start_of(span)
  if #span == 1 then
    span = spans[span]
  end
  local opts = {
    day =  { hour = 0, min = 0 },
    month = { day = 1, hour = 0, min = 0 },
    year = { month = 1, day = 1, hour = 0, min = 0 },
    hour = { min = 0 }
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
---@return Date
function Date:end_of(span)
  if #span == 1 then
    span = spans[span]
  end
  local opts = {
    day = { hour = 23, min = 59 },
    year = { month = 12, day = 31, hour = 23, min = 59 },
    hour = { min = 59 }
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

  if span == 'month'then
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
---@return Date
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
---@return string
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
---@return string
function Date:subtract(opts)
  opts = opts or {}
  for opt, val in pairs(opts) do
    opts[opt] = -val
  end
  return self:add(opts)
end

---@param date Date
---@param span string
---@return boolean
function Date:is_same(date, span)
  if not span then
    return self.timestamp == date.timestamp
  end
  return self:start_of(span).timestamp == date:start_of(span).timestamp
end

---@param from Date
---@param to Date
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

---@param date Date
---@param span string
---@return boolean
function Date:is_before(date, span)
  return not self:is_same_or_after(date, span)
end

---@param date Date
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

---@param date Date
---@param span string
---@return boolean
function Date:is_after(date, span)
  return not self:is_same_or_before(date, span)
end

---@param date Date
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
  return self:is_between(Date:new(), Date:new(), 'day')
end

---@param date Date
---@return Date[]
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
  return os.date(format, self.timestamp)
end

---@param from Date
---@return number
function Date:diff(from)
  local diff = self.timestamp - from.timestamp
  local day = 86400
  return math.floor(diff / day)
end

---@param span string
---@return boolean
function Date:is_past(span)
  return self:is_before(now(), span)
end

---@param span string
---@return string
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

---@param from Date
---@return string
function Date:humanize(from)
  from = from or now()
  local diff = self.timestamp - from.timestamp
  local is_past = diff < 0
  diff = math.abs(diff)
  local day = 86400
  if diff < day then
    return 'Today'
  end
  local count = math.floor(diff / day)
  if is_past then
    return count..' d. ago'
  end
  return 'In '..count..' d.'
end

---@return boolean
function Date:is_deadline()
  return self.active and self.type == 'DEADLINE'
end

function Date:is_none()
  return self.active and self.type == 'NONE'
end

---@return boolean
function Date:is_scheduled()
  return self.active and self.type == 'SCHEDULED'
end

---@return boolean
function Date:is_closed()
  return self.active and self.type == 'CLOSED'
end

---@return boolean
function Date:is_weekend()
  local isoweekday = self:get_isoweekday()
  return isoweekday >= 6
end

---@return string
function Date:get_warning_adjustment()
  if #self.adjustments == 0 then return nil end
  local adj = self.adjustments[#self.adjustments]
  if not adj:match('^%-%d+') then return nil end
  return adj
end

function Date:is_valid_for_today(today)
  if not self.active then
    return false
  end
  local is_same_day = self:is_same(today, 'day')
  local warning_date = self:get_warning_date()

  if self:is_none() or self:is_closed() then
    return is_same_day
  end

  if self:is_deadline() then
    if is_same_day then
      return true
    end
    local is_future = self:is_after(today, 'day')
    if is_future then
      return today:is_between(warning_date, self, 'day')
    end
    return true
  end

  if not self:get_warning_adjustment() then
    return is_same_day or self:is_before(today, 'day')
  end

  return warning_date:is_same_or_before(today, 'day')
end

function Date:is_valid_for_date(date)
  if not self.active then
    return false
  end
  if not self:get_warning_adjustment() or not self:is_scheduled() then
    return self:is_same(date, 'day')
  end

  return false
end

---@return Date
function Date:get_warning_date()
  if not self:is_deadline() and not self:is_scheduled() then
    return self
  end

  local adjustment = self:get_warning_adjustment()

  if self:is_deadline() then
    local warning_days = config.org_deadline_warning_days
    if adjustment then
      local adj = self:_parse_adjustment(adjustment)
      if adj.amount > warning_days then
        warning_days = adjustment.amount
      end
    end
    return self:subtract({ day = warning_days })
  end

  if not adjustment then return self end
  local adj = self:_parse_adjustment(adjustment)
  return self:add({ day = adj.amount })
end

---@return number
function Date:get_week_number()
  local start_of_year = self:start_of('year')
  local week = 1
  while start_of_year.timestamp < self.timestamp do
    start_of_year = start_of_year:add({ week = 1 })
    week = week + 1
  end
  return week
end

---@param line string
---@param lnum number
---@param open string
---@param datetime string
---@param close string
---@param last_match? Date
---@param type? string
---@return Date
local function from_match(line, lnum, open, datetime, close, last_match, type)
  local search_from = last_match and last_match.range.to.col or 0
  local from, to = line:find(vim.pesc(open..datetime..close), search_from)
  return from_string(vim.trim(datetime), {
    type = type,
    active = open == '<',
    range = {
      from = { line = lnum, col = from },
      to = { line = lnum, col = to }
    }
  })
end

---@param line string
---@param lnum number
---@return Date[]
local function parse_all_from_line(line, lnum)
  local dates = {}
  for open, datetime, close in line:gmatch(pattern) do
    table.insert(dates, from_match(line, lnum, open, datetime, close, dates[#dates]))
  end
  return dates
end

return {
  from_string = from_string,
  now = now,
  parse_all_from_line = parse_all_from_line,
  from_match = from_match,
  pattern = pattern
}

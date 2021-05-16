local Date = {}
local spans = { d = 'day', m = 'month', y = 'year', h = 'hour', w = 'week' }
local config = require('orgmode').config

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
function Date:new(data)
  data = data or {}
  local date_only = data.date_only or (not data.hour and not data.min)
  local opts = set_date_opts(data)
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

function Date:from_time_table(time)
  local timestamp = os.time(set_date_opts(time))
  local opts = set_date_opts(os.date('*t', timestamp))
  opts.date_only = self.date_only
  opts.dayname = self.dayname
  opts.adjustments = self.adjustments
  return Date:new(opts)
end

function Date:set(opts)
  opts = opts or {}
  local date = os.date('*t', self.timestamp)
  for opt, val in pairs(opts) do
    date[opt] = val
  end
  return self:from_time_table(date)
end

local function parse_datetime(date, dayname, time, adjustments)
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
  return Date:new(opts)
end

local function parse_date(date, dayname, adjustments)
  local date_parts = vim.split(date, '-')
  local opts = {
    year = tonumber(date_parts[1]),
    month = tonumber(date_parts[2]),
    day = tonumber(date_parts[3]),
  }
  opts.adjustments = adjustments
  opts.dayname = dayname
  return Date:new(opts)
end

local function from_string(datestr)
  if not datestr:match('^%d%d%d%d%-%d%d%-%d%d$') and not datestr:match('^%d%d%d%d%-%d%d%-%d%d%s+') then
    return Date:new()
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
    return parse_datetime(date, dayname, time, adjustments)
  end

  return parse_date(date, dayname, adjustments)
end

local function now()
  return Date:new()
end

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

function Date:adjust(value)
  local operation, amount, span = value:match('^([%+%-])(%d+)([hdwmy]?)')
  if not operation or not amount then
    return self
  end
  if not span or span == '' then
    span = 'd'
  end
  span = spans[span]
  local adjustment = { [span] = tonumber(amount) }
  if operation == '+' then
    return self:add(adjustment)
  end
  return self:subtract(adjustment)
end

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

function Date:subtract(opts)
  opts = opts or {}
  for opt, val in pairs(opts) do
    opts[opt] = -val
  end
  return self:add(opts)
end

function Date:is_same(date, span)
  if not span then
    return self.timestamp == date.timestamp
  end
  return self:start_of(span).timestamp == date:start_of(span).timestamp
end

function Date:is_between(from, to)
  return self.timestamp >= from.timestamp and self.timestamp <= to.timestamp
end

function Date:is_before(date)
  return self.timestamp < date.timestamp
end

function Date:is_same_or_before(date)
  return self.timestamp <= date.timestamp
end

function Date:is_after(date)
  return self.timestamp > date.timestamp
end

function Date:is_same_or_after(date)
  return self.timestamp >= date.timestamp
end

function Date:is_today()
  return self:is_between(Date:new():start_of('day'), Date:new():end_of('day'))
end

function Date:get_range_until(date)
  local this = self
  local dates = {}
  while this.timestamp < date.timestamp do
    table.insert(dates, this)
    this = this:add({ day = 1 })
  end
  return dates
end

function Date:format(format)
  return os.date(format, self.timestamp)
end

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

return {
  from_string = from_string,
  now = now,
}

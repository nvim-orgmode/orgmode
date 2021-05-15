local Date = {}

local date_pattern = '^(%d%d%d%d)-(%d%d)-(%d%d)%s+%a%a%a$'
local date_time_pattern = '^(%d%d%d%d)-(%d%d)-(%d%d)%s+%a%a%a%s+(%d?%d:%d%d)$'
local adjustment_pattern = '(%s+[%.%+%-][%+%-%s%dhdwmy]+)$'

-- TODO: Support diary format and format without short date name
function Date:new(data)
  data = data or {}
  local opts = {}
  opts.year = data.year
  opts.month = data.month
  opts.day = data.day
  opts.date_only = data.date_only or (not data.hour and not data.min)
  opts.hour = data.hour or 0
  opts.min = data.min or 0
  if opts.year and opts.month and opts.day then
    opts.timestamp = os.time(opts)
  end
  opts.valid = data.valid or false
  opts.adjustment = data.adjustment
  opts.original_value = data.original_value
  setmetatable(opts, self)
  self.__index = self
  return opts
end

function Date:from_string(date, adjustment)
  local adjustment_match = date:match(adjustment_pattern)
  local date_part = date
  if not adjustment and adjustment_match then
    adjustment = vim.trim(adjustment_match)
    date_part = date_part:gsub(adjustment_pattern, '')
  end
  if date_part:match(date_time_pattern) then
    return Date:_parse_datetime(date, adjustment)
  end
  if date_part:match(date_pattern) then
    return Date:_parse_date(date, adjustment)
  end
  return Date:new()
end

function Date:to_string()
  if not self.valid then return '' end
  local date = ''

  if self.date_only then
    date = os.date('%Y-%m-%d %a', self.timestamp)
  else
    date = os.date('%Y-%m-%d %a %H:%M', self.timestamp)
  end

  if self.adjustment then
    date = date..' '..self.adjustment
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
  if span == 'w' then
    span = 'd'
    amount = tonumber(amount) * 7
  end
  local spans = { d = 'day', m = 'month', y = 'year', h = 'hour', w = 'week' }
  local opts = {
    year = self.year,
    month = self.month,
    day = self.day,
    hour = self.hour,
    min = self.min,
  }
  if spans[span] then
    if operation == '+' then
      opts[spans[span]] = opts[spans[span]] + tonumber(amount)
    elseif operation == '-' then
      opts[spans[span]] = opts[spans[span]] - tonumber(amount)
    end
  end
  local new_date = os.date('*t', os.time(opts))
  for k,_ in pairs(opts) do
    opts[k] = new_date[k]
  end
  opts.valid = true
  opts.adjustment = self.adjustment
  opts.date_only = self.date_only
  return Date:new(opts)
end

function Date:_parse_datetime(value, adjustment)
  local date = value:gsub(adjustment_pattern, '')
  local Y,M,D,T = date:match(date_time_pattern)
  local time = vim.split(T, ':')
  local opts = {
    year = tonumber(Y),
    month = tonumber(M),
    day = tonumber(D),
    hour = tonumber(time[1]),
    min = tonumber(time[2]),
  }
  local date_part = date:gsub('%s+'..T..'$', '')
  local valid = os.date('%Y-%m-%d %a', os.time(opts)) == date_part and true or false
  opts.adjustment = adjustment
  if valid then
    local hour_valid = opts.hour >= 0 and opts.hour <= 23 and true or false
    local minute_valid = opts.hour >= 0 and opts.hour <= 59 and true or false
    valid = hour_valid and minute_valid
  end
  opts.valid = valid
  opts.original_value = value
  return Date:new(opts)
end

function Date:_parse_date(value, adjustment)
  local date = value:gsub(adjustment_pattern, '')
  local Y,M,D = value:match(date_pattern)
  local opts = {
    year = tonumber(Y),
    month = tonumber(M),
    day = tonumber(D),
  }
  opts.adjustment = adjustment
  opts.valid = os.date('%Y-%m-%d %a', os.time(opts)) == date and true or false
  opts.original_value = value
  opts.date_only = true
  return Date:new(opts)
end

return Date

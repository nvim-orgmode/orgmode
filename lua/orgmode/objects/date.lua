local Date = {}

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
  else
    opts.timestamp = os.time()
    local date = os.date('*t', opts.timestamp)
    opts.year = date.year
    opts.month = date.month
    opts.day = date.day
    opts.hour = date.hour
    opts.minute = date.minute
  end
  opts.dayname = data.dayname
  opts.adjustments = data.adjustments or {}
  opts.original_value = data.original_value
  setmetatable(opts, self)
  self.__index = self
  return opts
end

local function parse_datetime(datestr, date, dayname, time, adjustments)
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
  opts.original_value = datestr
  return Date:new(opts)
end

local function parse_date(datestr, date, dayname, adjustments)
  local date_parts = vim.split(date, '-')
  local opts = {
    year = tonumber(date_parts[1]),
    month = tonumber(date_parts[2]),
    day = tonumber(date_parts[3]),
  }
  opts.adjustments = adjustments
  opts.dayname = dayname
  opts.original_value = datestr
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
    return parse_datetime(datestr, date, dayname, time, adjustments)
  end

  return parse_date(datestr, date, dayname, adjustments)
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
  opts.adjustments = self.adjustments
  opts.date_only = self.date_only
  opts.dayname = self.dayname
  return Date:new(opts)
end

return {
  from_string = from_string
}

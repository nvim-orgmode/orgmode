---@class OrgDuration
---@field parts table
---@field minutes number
local Duration = {}
local hour_minute_pattern = '(%d+):(%d+)$'

local parse_hours_minutes = function(str, on_end)
  local pattern = hour_minute_pattern
  if not on_end then
    pattern = '^' .. pattern
  end
  local hh, mm = str:match(pattern)
  if not hh or not mm then
    return nil
  end
  local parts = {
    hours = tonumber(hh),
    minutes = tonumber(mm),
  }
  return Duration:new({
    parts = parts,
    minutes = parts.hours * 60 + parts.minutes,
  })
end

local valid_formats = {
  {
    format = 'HH:MM',
    parse = function(str)
      return parse_hours_minutes(str, false)
    end,
  },
  {
    format = '%d(hdwmy)+',
    parse = function(str)
      local map = {
        h = {
          name = 'hours',
          calc = function(val)
            return tonumber(val) * 60
          end,
        },
        d = {
          name = 'days',
          calc = function(val)
            return tonumber(val) * 60 * 24
          end,
        },
        w = {
          name = 'weeks',
          calc = function(val)
            return tonumber(val) * 60 * 24 * 7
          end,
        },
        m = {
          name = 'months',
          calc = function(val)
            return tonumber(val) * 60 * 24 * 30
          end,
        },
        y = {
          name = 'years',
          calc = function(val)
            return tonumber(val) * 60 * 24 * 365
          end,
        },
        min = {
          name = 'minutes',
          calc = function(val)
            return tonumber(val)
          end,
        },
      }
      local result = {
        parts = {},
        minutes = 0,
      }

      local hours_minutes = parse_hours_minutes(str, true)
      if hours_minutes then
        result.parts.hours = hours_minutes.parts.hours
        result.parts.minutes = hours_minutes.parts.minutes
        result.minutes = hours_minutes.minutes

        str = vim.trim(str:gsub(hour_minute_pattern, ''))
      end

      for num, type in string.gmatch(str, '(%d+)([%a]+)') do
        if not num or not type or not map[type:lower()] then
          return nil
        end
        local item = map[type:lower()]
        result.parts[item.name] = (result.parts[item.name] or 0) + tonumber(num)
        result.minutes = result.minutes + item.calc(num)
      end

      if vim.tbl_isempty(result.parts) then
        return nil
      end

      return Duration:new(result)
    end,
  },
}

---@param seconds number
---@returns Duration
local function from_seconds(seconds)
  local minutes = math.floor(seconds / 60)
  return Duration:new({
    parts = { minutes = minutes },
    minutes = minutes,
  })
end

---@param minutes number
---@returns Duration
local function from_minutes(minutes)
  return Duration:new({
    parts = { minutes = minutes },
    minutes = minutes,
  })
end

function Duration:new(opts)
  local data = {}
  data.parts = opts.parts or {}
  data.minutes = opts.minutes or 0
  setmetatable(data, self)
  self.__index = self
  return data
end

function Duration:to_string(format)
  local hour_minute_format = function()
    local hours = math.floor(self.minutes / 60)
    local minutes = self.minutes % 60
    return string.format('%d:%02d', hours, minutes)
  end
  local formats = {
    ['HH:MM'] = hour_minute_format,
    default = function()
      -- Less than 24 hours
      if self.minutes < 1440 then
        return hour_minute_format()
      end

      local delta = self.minutes

      local durations = {
        { name = 'y', val = 24 * 60 * 365 },
        { name = 'm', val = 24 * 60 * 30 },
        { name = 'w', val = 24 * 60 * 7 },
        { name = 'd', val = 24 * 60 },
      }
      local result = {}

      for _, duration in ipairs(durations) do
        local amount = math.floor(delta / duration.val)
        delta = delta - (amount * duration.val)
        if amount > 0 then
          table.insert(result, string.format('%d%s', amount, duration.name))
        end
      end

      if delta > 0 then
        local hour_minute_duration = from_minutes(delta)
        table.insert(result, hour_minute_duration:to_string('HH:MM'))
      end

      return table.concat(result, ' ')
    end,
  }

  return formats[format] and formats[format]() or formats.default()
end

---@param val string
---@returns Duration|nil
local function parse(val)
  for _, format in ipairs(valid_formats) do
    local parsed = format.parse(val)
    if parsed ~= nil then
      return parsed
    end
  end
  return nil
end

return {
  parse = parse,
  from_seconds = from_seconds,
  from_minutes = from_minutes,
}

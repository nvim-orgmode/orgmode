local DateObj = require('orgmode.objects.date')
local Date = {}
local pattern = '([<%[])(%d%d%d%d%-%d?%d%-%d%d[^>%]]*)([>%]])'

function Date:new(opts)
  opts = opts or {}
  local data = {}
  data.valid = opts.valid or false
  data.type = opts.type or 'NONE'
  data.active = opts.active or false
  data.range = opts.range
  data.date = opts.date
  setmetatable(data, self)
  self.__index = self
  return data
end

local function from_match(line, lnum, open, datetime, close, last_match, type)
  local date = DateObj.from_string(vim.trim(datetime))
  local open_type = open == '<' and 'active' or 'inactive'
  local close_type = close == '>' and 'active' or 'inactive'
  local valid = date.valid and open_type == close_type
  local search_from = last_match and last_match.range.to.col or 0
  local from, to = line:find(vim.pesc(open..datetime..close), search_from)
  return Date:new({
    type = type,
    date = date,
    active = open_type == 'active',
    valid = valid,
    range = {
      from = { line = lnum, col = from },
      to = { line = lnum, col = to }
    }
  })
end

local function parse_all_from_line(line, lnum)
  local dates = {}
  for open, datetime, close in line:gmatch(pattern) do
    local date = from_match(line, lnum, open, datetime, close, dates[#dates])
    if date.valid then
      table.insert(dates, date)
    end
  end
  return dates
end

return {
  parse_all_from_line = parse_all_from_line,
  from_match = from_match,
  pattern = pattern
}

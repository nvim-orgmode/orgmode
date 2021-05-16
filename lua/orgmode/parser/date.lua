local DateObj = require('orgmode.objects.date')
local Date = {}
local pattern = '([<%[])(%d%d%d%d%-%d?%d%-%d%d[^>%]]*)([>%]])'

function Date:new(opts)
  opts = opts or {}
  local data = {}
  data.type = opts.type or 'NONE'
  data.active = opts.active or false
  data.range = opts.range
  data.date = opts.date
  setmetatable(data, self)
  self.__index = self
  return data
end

function Date:is_deadline(date)
  return self.active and self.type == 'DEADLINE' and self.date:is_same(date, 'day')
end

function Date:is_scheduled(date)
  return self.active and self.type == 'SCHEDULED' and self.date:is_same(date, 'day')
end

function Date:is_valid_for_agenda(date)
  return self.active and vim.tbl_contains({'DEADLINE', 'SCHEDULED', 'NONE'}, self.type) and self.date:is_same(date, 'day')
end

local function from_match(line, lnum, open, datetime, close, last_match, type)
  local date = DateObj.from_string(vim.trim(datetime))
  local search_from = last_match and last_match.range.to.col or 0
  local from, to = line:find(vim.pesc(open..datetime..close), search_from)
  return Date:new({
    type = type,
    date = date,
    active = open == '<',
    range = {
      from = { line = lnum, col = from },
      to = { line = lnum, col = to }
    }
  })
end

local function parse_all_from_line(line, lnum)
  local dates = {}
  for open, datetime, close in line:gmatch(pattern) do
    table.insert(dates, from_match(line, lnum, open, datetime, close, dates[#dates]))
  end
  return dates
end

return {
  parse_all_from_line = parse_all_from_line,
  from_match = from_match,
  pattern = pattern
}

local Content = {}
local Types = require('orgmode.parser.types')
local DateParser = require('orgmode.parser.date')
local plannings = {'DEADLINE', 'SCHEDULED', 'CLOSED'}

function Content:new(data)
  data = data or {}
  local content = { type = Types.CONTENT }
  content.parent = data.parent.id
  content.level = data.parent.level
  content.line = data.line
  content.range = {
      from = { line = data.lnum, col = 1 },
      to = { line = data.lnum, col = 1 },
  }
  content.id = data.lnum
  setmetatable(content, self)
  self.__index = self
  content:parse()
  return content
end

function Content:is_keyword()
  return self.type == Types.KEYWORD
end

function Content:is_planning()
  return self.type == Types.PLANNING
end

function Content:parse()
  local keyword = self:_parse_keyword()
  if keyword then return self end

  local planning = self:_parse_planning()
  if planning then return self end

  local dates = DateParser.parse_all_from_line(self.line, self.range.from.line)
  for _, date in ipairs(dates) do
    table.insert(self.dates, date)
  end
end

function Content:_parse_keyword()
  local keyword = self.line:match('^%s*#%+%S+:')
  if not keyword then return false end
  self.type = Types.KEYWORD
  self.keyword = {
    name = keyword:gsub('^%s*#%+', ''):sub(1, -2),
    value = vim.trim(self.line:sub(#keyword + 1))
  }
  return true
end

function Content:_parse_planning()
  local is_planning = false
  for _, planning in ipairs(plannings) do
    if self.line:match('^%s*'..planning..':%s*'..DateParser.pattern) then
      is_planning = true
      break
    end
  end
  if not is_planning then return false end
  self.type = Types.PLANNING
  self.dates = self.dates or {}
  local dates = {}
  for _, planning in ipairs(plannings) do
    for plan, open, datetime, close in self.line:gmatch('('..planning..'):%s*'..DateParser.pattern) do
      local date = DateParser.from_match(self.line, self.range.from.line, open, datetime, close, dates[#dates], plan)
      table.insert(dates, date)
    end
  end
  for _, date in ipairs(dates) do
    table.insert(self.dates, date)
  end
  return true
end

return Content

local Types = require('orgmode.parser.types')
local Range = require('orgmode.parser.range')
local Date = require('orgmode.objects.date')
local plannings = {'DEADLINE', 'SCHEDULED', 'CLOSED'}

---@class Content
---@field parent string
---@field range Range
---@field line string
---@field dates Date[]
---@field id string
local Content = {}

---@param data table
function Content:new(data)
  data = data or {}
  local content = { type = Types.CONTENT }
  content.parent = data.parent.id
  content.level = data.parent.level
  content.line = data.line
  content.range = Range.from_line(data.lnum)
  content.dates = {}
  content.id = data.lnum
  setmetatable(content, self)
  self.__index = self
  content:parse()
  return content
end

---@return boolean
function Content:is_keyword()
  return self.type == Types.KEYWORD
end

---@return boolean
function Content:is_planning()
  return self.type == Types.PLANNING
end

function Content:parse()
  local keyword = self:_parse_keyword()
  if keyword then return self end

  local planning = self:_parse_planning()
  if planning then return self end

  local dates = Date.parse_all_from_line(self.line, self.range.start_line)
  for _, date in ipairs(dates) do
    table.insert(self.dates, date)
  end
end

---@return boolean
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

---@return boolean
function Content:_parse_planning()
  local is_planning = false
  for _, planning in ipairs(plannings) do
    if self.line:match('^%s*'..planning..':%s*'..Date.pattern) then
      is_planning = true
      break
    end
  end
  if not is_planning then return false end
  self.type = Types.PLANNING
  local dates = {}
  for _, planning in ipairs(plannings) do
    for plan, open, datetime, close in self.line:gmatch('('..planning..'):%s*'..Date.pattern) do
      local date = Date.from_match(self.line, self.range.start_line, open, datetime, close, dates[#dates], plan)
      table.insert(dates, date)
    end
  end
  for _, date in ipairs(dates) do
    table.insert(self.dates, date)
  end
  return true
end

return Content

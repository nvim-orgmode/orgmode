local Content = {}
local Types = require('orgmode.parser.types')
local Date = require('orgmode.objects.date')
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

  self:_parse_dates()
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
    if self.line:match('^%s*'..planning..':%s*<[^>]*>') then
      is_planning = true
      break
    end
  end
  if not is_planning then return false end
  self.type = Types.PLANNING
  self.dates = self.dates or {}
  for _, planning in ipairs(plannings) do
    for plan, datetime in self.line:gmatch('('..planning..')'..':%s*<([^>]*)>') do
      local date = Date:from_string(vim.trim(datetime))
      if date.valid then
        table.insert(self.dates, { type = plan, date = date })
      end
    end
  end
  return true
end

function Content:_parse_dates()
  for datetime in self.line:gmatch('<([^>]*)>') do
    local date = Date:from_string(vim.trim(datetime))
    if date.valid then
      self.dates = self.dates or {}
      table.insert(self.dates, date)
    end
  end
end

return Content

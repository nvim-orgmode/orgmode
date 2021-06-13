local Types = require('orgmode.parser.types')
local Range = require('orgmode.parser.range')
local Date = require('orgmode.objects.date')
local plannings = {'DEADLINE', 'SCHEDULED', 'CLOSED'}

---@class Content
---@field parent Headline|Root
---@field range Range
---@field line string
---@field dates Date[]
---@field properties table
---@field keyword table
---@field drawer table
---@field content table
---@field id string
local Content = {}

---@param data table
function Content:new(data)
  data = data or {}
  local content = { type = Types.CONTENT }
  content.parent = data.parent
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

---@return boolean
function Content:is_content()
  return true
end

---@return boolean
function Content:is_headline()
  return false
end

function Content:is_plain_list()
  return self.line:match('^%s*[%+%-]%s*')
end

function Content:is_checkbox()
  return self.line:match('^(%s*[%+%-])%s*%[[%sXx%-]?%]')
end

---@return boolean
function Content:is_drawer()
  return self.type == Types.DRAWER
end

function Content:is_commented()
  return self.line:match('^%s*#%s')
end

---@return boolean
function Content:is_parent_start()
  return self:is_drawer() and self.drawer.name
end

---@return string
function Content:is_parent_end()
  return self:is_drawer() and self.drawer.ended
end

function Content:is_block_src_start()
  return self.line:match('^%s*#%+BEGIN_SRC%s+.*$')
end

---@return boolean
function Content:is_properties_start()
  return self:is_parent_start() and self.drawer.name == 'PROPERTIES'
end

function Content:parse()
  if self:is_commented() then return end

  local dates = Date.parse_all_from_line(self.line, self.range.start_line)
  for _, date in ipairs(dates) do
    table.insert(self.dates, date)
  end

  local keyword = self:_parse_keyword()
  if keyword then return self end

  local planning = self:_parse_planning()
  if planning then return self end

  local drawer = self:_parse_drawer()
  if drawer then return self end

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
  for _, date in ipairs(self.dates) do
    local line_content = self.line:sub(1, date.range.end_col)
    local plan = line_content:match('([A-Z]*):?%s*'..Date.pattern..'$')
    if plan and vim.tbl_contains(plannings, plan) then
      date.type = plan
    end
  end
  return true
end

---@return boolean
function Content:_parse_drawer()
  local drawer_end = self.line:match('^%s*:END:%s*$')
  if drawer_end then
    self.drawer = { ended = true }
    self.type = Types.DRAWER
    return true
  end
  local drawer_start = self.line:match('^%s*:([^:]*):%s*$')
  if drawer_start then
    self.type = Types.DRAWER
    self.drawer = {
      name = drawer_start
    }
    return true
  end
  local drawer_prop_name, drawer_prop_value = self.line:match('^%s*:([^:]-):%s*(.*)$')
  if drawer_prop_name and drawer_prop_value then
    self.type = Types.DRAWER
    self.drawer = {
      properties = {
        [drawer_prop_name] =  drawer_prop_value
      }
    }
    return true
  end
  return false
end

return Content

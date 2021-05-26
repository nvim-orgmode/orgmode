local Types = require('orgmode.parser.types')
local Date = require('orgmode.objects.date')
local Range = require('orgmode.parser.range')
local config = require('orgmode.config')

---@class Headline
---@field id number
---@field level number
---@field parent Headline|Root
---@field line string
---@field range Range
---@field content Content[]
---@field headlines Headline[]
---@field todo_keyword table<string, string>
---@field priority string
---@field title string
---@field category string
---@field properties table
---@field file string
---@field dates Date[]
---@field tags string[]
local Headline = {}

---@param data table
function Headline:new(data)
  data = data or {}
  local headline = { type = Types.HEADLINE }
  headline.id = data.lnum
  headline.level = data.line and #data.line:match('^%*+') or 0
  headline.parent = data.parent
  headline.line = data.line
  headline.range = Range.from_line(data.lnum)
  headline.content = {}
  headline.headlines = {}
  headline.todo_keyword = { value = '', type = '' }
  headline.priority = ''
  headline.title = ''
  headline.category = data.category or ''
  headline.file = data.file or ''
  headline.dates = {}
  headline.properties = {}
  -- TODO: Add configuration for
  -- - org-use-tag-inheritance
  -- - org-tags-exclude-from-inheritance
  -- - org-tags-match-list-sublevels
  headline.tags = {unpack(data.parent.tags or {})}
  setmetatable(headline, self)
  self.__index = self
  headline:_parse_line()
  return headline
end

---@param headline Headline
---@return Headline
function Headline:add_headline(headline)
  table.insert(self.headlines, headline)
  return headline
end

---@return boolean
function Headline:is_done()
  return vim.tbl_contains(config:get_todo_keywords().DONE, self.todo_keyword.value:upper())
end

---@return boolean
function Headline:is_todo()
  return vim.tbl_contains(config:get_todo_keywords().TODO, self.todo_keyword.value:upper())
end

-- TODO: Check if this can be configured to be ignored
---@return boolean
function Headline:is_archived()
  return #vim.tbl_filter(function(tag) return tag:upper() == 'ARCHIVE' end, self.tags) > 0
    or self:get_category():upper() == 'ARCHIVE'
end

---@return boolean
function Headline:has_deadline()
  for _, date in ipairs(self.dates) do
    if date:is_deadline() then return true end
  end
  return false
end

---@return boolean
function Headline:has_scheduled()
  for _, date in ipairs(self.dates) do
    if date:is_scheduled() then return true end
  end
  return false
end

---@return boolean
function Headline:has_closed()
  for _, date in ipairs(self.dates) do
    if date:is_closed() then return true end
  end
  return false
end

---@param content Content
function Headline:_parse_planning(content)
  if content:is_planning() and vim.tbl_isempty(self.content) then
    for _, plan in ipairs(content.dates) do
      table.insert(self.dates, plan)
    end
    return true
  end
  return false
end

---@param content Content
function Headline:_parse_dates(content)
  if content.dates then
    for _, date in ipairs(content.dates) do
      table.insert(self.dates, date:clone({ type = 'NONE' }))
    end
  end
end

---@param content Content
function Headline:_parse_properties(content)
  if content:is_parent_end() then
    local properties_start_index = self:_get_properties_start_index()
    if properties_start_index then
      local start_index = properties_start_index + 1
      while start_index < #self.content do
        local property = self.content[start_index]
        if property.drawer and property.drawer.properties then
          self.properties = vim.tbl_extend('force', self.properties, property.drawer.properties or {})
        end
        start_index = start_index + 1
      end
    end
  end
end

function Headline:_get_properties_start_index()
  local properties_start_index = nil
  local len = #self.content
  for i=1, len do
    local idx = len + 1 - i
    local item = self.content[idx]
    if item:is_properties_start() then
      properties_start_index = idx
      break
    end
  end
  return properties_start_index
end

---@param content Content
---@return Content
function Headline:add_content(content)
  local is_planning = self:_parse_planning(content)
  if not is_planning then
    self:_parse_dates(content)
  end
  table.insert(self.content, content)
  self:_parse_properties(content)
  return content
end

---@param lnum number
function Headline:set_range_end(lnum)
  self.range.end_line = lnum
end

---@return string
function Headline:tags_to_string()
  local tags = ''
  if #self.tags > 0 then
    tags = ':'..table.concat(self.tags, ':')..':'
  end
  return tags
end

function Headline:get_valid_dates()
  return vim.tbl_filter(function(date)
    return date.active and not date:is_closed()
  end, self.dates)
end

function Headline:_parse_line()
  local line = self.line
  line = line:gsub('^%*+%s+', '')

  self:_parse_todo_keyword()
  self.priority = line:match(self.todo_keyword.value..'%s+%[#([A-Z0-9])%]') or ''
  local parsed_tags = self:_parse_tags(line)
  self:_parse_title(line, parsed_tags)
  local dates = Date.parse_all_from_line(self.line, self.range.start_line)
  for _, date in ipairs(dates) do
    table.insert(self.dates, date)
  end
end

function Headline:_parse_todo_keyword()
  local todo_keywords = config:get_todo_keywords()
  for _, word in ipairs(todo_keywords.ALL) do
    local star = self.line:match('^%*+%s+')
    local keyword = self.line:match('^%*+%s+'..word..'%s+')
    -- If keyword doesn't have a space after it, check if whole line
    -- is just a keyword. For example: "* DONE"
    if not keyword then
      keyword = self.line == star..word
    end
    if keyword then
      local type = 'TODO'
      if vim.tbl_contains(todo_keywords.DONE, word) then
        type = 'DONE'
      end
      self.todo_keyword = {
        value = word,
        type = type,
        range = Range:new({
          start_line = self.range.start_line,
          end_line = self.range.start_line,
          start_col = #star + 1,
          end_col = #star + #word,
        })
      }
      break
    end
  end
end

function Headline:_parse_tags(line)
  local tags = line:match(':.*:$') or ''
  local parsed_tags = {}
  if tags then
    for _, tag in ipairs(vim.split(tags, ':')) do
      if tag:find('^[%w_%%@#]+$') then
        table.insert(parsed_tags, tag)
        if not vim.tbl_contains(self.tags, tag) then
          table.insert(self.tags, tag)
        end
      end
    end
  end
  return parsed_tags
end

-- NOTE: Exclude dates from title if it appears in agenda on that day
function Headline:_parse_title(line, tags)
  local title = line
  for _, exclude_pattern in ipairs({ self.todo_keyword.value, '%[#[A-Z0-9]%]', vim.pesc(':'..table.concat(tags, ':')..':')..'$' }) do
    title = title:gsub(exclude_pattern, '')
  end
  self.title = vim.trim(title)
end

function Headline:get_category()
  if self.properties.CATEGORY then
    return self.properties.CATEGORY
  end
  return self.category
end

return Headline

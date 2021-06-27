local Types = require('orgmode.parser.types')
local Date = require('orgmode.objects.date')
local Range = require('orgmode.parser.range')
local config = require('orgmode.config')
local utils = require('orgmode.utils')

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
---@field archived boolean
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
  headline.properties = { items = {} }
  headline.archived = data.archived or false
  headline.tags = config:get_inheritable_tags(data.parent)
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
function Headline:is_headline()
  return true
end

---@return boolean
function Headline:is_content()
  return false
end

---@return boolean
function Headline:is_first_headline()
  return self.parent.headlines[1].id == self.id
end

---@return boolean
function Headline:is_last_headline()
  return self.parent.headlines[#self.parent.headlines].id == self.id
end

function Headline:has_priority()
  return self.priority ~= ''
end

function Headline:get_priority_number()
  if self.priority == config.org_priority_highest then return 2000 end
  if self.priority == config.org_priority_lowest then return 0 end
  return 1000
end

function Headline:get_next_headline_same_level()
  if self:is_last_headline() then return nil end
  for _, headline in ipairs(self.parent.headlines) do
    if headline.id > self.id and headline.level == self.level then
      return headline
    end
  end
  return nil
end

function Headline:get_prev_headline_same_level()
  if self:is_first_headline() then return nil end
  local len = #self.parent.headlines
  for i = 1, len do
    local headline = self.parent.headlines[len + 1 - i]
    if headline.id < self.id and headline.level == self.level then
      return headline
    end
  end
  return nil
end

---@return boolean
function Headline:is_done()
  return self.todo_keyword.type == 'DONE'
end

---@return boolean
function Headline:is_todo()
  return self.todo_keyword.type == 'TODO'
end

---@param name string
---@return string|nil
function Headline:get_property(name)
  return self.properties.items[name]
end

---@param properties table<string,string>
---@return table
function Headline:add_properties(properties)
  if self.properties.valid then
    local start = self:_get_content_by_lnum(self.properties.range.start_line)
    local indent = start.line:match('^%s*')
    for name, val in pairs(properties) do
      if self.properties.items[name] then
        local existing = self:_get_content_with_property(name, self.properties.items[name])
        if existing then
          local new_line = existing.line:gsub(vim.pesc(self.properties.items[name]), val)
          vim.api.nvim_call_function('setline', { existing.range.start_line, new_line })
        end
      else
        vim.api.nvim_call_function('append', {
          self.properties.range.start_line,
          string.format('%s:%s: %s', indent, name, val),
        })
      end
    end
    return {
      is_new = false,
    }
  end

  local properties_line = self:_get_new_properties_line()
  local indent = string.rep(' ', self.level + 1)
  local content = { string.format('%s:PROPERTIES:', indent) }

  for name, val in pairs(properties) do
    table.insert(content, string.format('%s:%s: %s', indent, name, val))
  end

  table.insert(content, string.format('%s:END:', indent))
  vim.api.nvim_call_function('append', { properties_line, content })
  return {
    is_new = true,
    end_line = properties_line + #content
  }
end

function Headline:_get_content_with_property(property, val)
  local contents = vim.tbl_filter(function(content)
    return content:is_drawer() and content.drawer.properties and content.drawer.properties[property] == val
  end, self.content)
  return contents[1]
end

function Headline:_get_new_properties_line()
  if #self.content == 0 or not self.content[1]:is_planning() then
    return self.range.start_line
  end
  return self.content[1].range.start_line
end

---@return boolean
function Headline:is_archived()
  return self.archived or #vim.tbl_filter(function(tag) return tag:upper() == 'ARCHIVE' end, self.tags) > 0
end

---@return Date[]
function Headline:get_repeater_dates()
  return vim.tbl_filter(function(date)
    return date:get_repeater()
  end, self.dates)
end

function Headline:_get_content_by_lnum(lnum)
  return self.content[lnum - self.range.start_line]
end

function Headline:get_content_matching(val)
  for _, content in ipairs(self.content) do
    if content.line:match(val) then
      return content
    end
  end
  return nil
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
  if content:is_properties_start() then
    if not self.properties.range then
      self.properties.range = Range.from_line(content.range.start_line)
    end
  end
  if content:is_parent_end() then
    if self.properties.range and self.properties.range:is_same_line() then
      self.properties.range.end_line = content.range.start_line
      self.properties.valid = true
      local start_index = self.properties.range.start_line - self.range.start_line
      local end_index = self.properties.range.end_line - self.range.start_line
      while start_index < end_index do
        local entry = self.content[start_index]
        if entry.drawer and entry.drawer.properties then
          self.properties.items = vim.tbl_extend('force', self.properties.items, entry.drawer.properties or {})
        end
        start_index = start_index + 1
      end
    end
  end
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
  return utils.tags_to_string(self.tags)
end

function Headline:_get_closed_date()
  return vim.tbl_filter(function(date)
    return date:is_closed()
  end, self.dates)[1]
end

function Headline:add_closed_date()
  local closed_date = self:_get_closed_date()
  if closed_date then return nil end
  local planning = self.content[1]
  if planning and planning:is_planning() then
    return vim.api.nvim_call_function('setline', {
      planning.range.start_line,
      string.format('%s CLOSED: [%s]', planning.line, Date.now():to_string())
    })
  end
  return vim.api.nvim_call_function('append', {
    self.range.start_line,
    string.format('%sCLOSED: [%s]', string.rep(' ', self.level + 1), Date.now():to_string())
  })
end

function Headline:remove_closed_date()
  local closed_date = self:_get_closed_date()
  if not closed_date then return nil end
  local planning = self.content[1]
  local new_line = planning.line:gsub('%s*CLOSED:%s*[%[<]'..vim.pesc(closed_date:to_string())..'[%]>]', '')
  if vim.trim(new_line) == '' then
    return vim.api.nvim_call_function('deletebufline', { vim.api.nvim_get_current_buf(), planning.range.start_line })
  end
  return vim.api.nvim_call_function('setline', { planning.range.start_line, new_line })
end

function Headline:get_valid_dates_for_agenda()
  local dates = {}
  for i, date in ipairs(self.dates) do
    if date.active and not date:is_closed() and not date:is_obsolete_range_end() then
      table.insert(dates, date)
      if not date:is_none() and date.is_date_range_start then
        local new_date = date:clone({ type = 'NONE' })
        table.insert(dates, new_date)
      end
    end
  end
  return dates
end

--- Get list of tags that are directly applied to this headline
---@return string
function Headline:get_own_tags()
  return utils.parse_tags_string(self.line:match(':.*:$'))
end

function Headline:demote(amount, demote_child_headlines)
  amount = amount or 1
  demote_child_headlines = demote_child_headlines or false
  vim.fn.setline(self.range.start_line, string.rep('*', amount)..self.line)
  for _, content in ipairs(self.content) do
    vim.fn.setline(content.range.start_line, string.rep(' ', amount)..content.line)
  end
  if demote_child_headlines then
    for _, headline in ipairs(self.headlines) do
      headline:demote(amount, true)
    end
  end
end

function Headline:promote(amount, promote_child_headlines)
  amount = amount or 1
  promote_child_headlines = promote_child_headlines or false
  if self.level == 1 then
    return utils.echo_warning('Cannot demote top level heading.')
  end
  vim.fn.setline(self.range.start_line, self.line:sub(1 + amount))
  for _, content in ipairs(self.content) do
    if vim.trim(content.line:sub(1, amount)) == '' then
      vim.fn.setline(content.range.start_line, content.line:sub(1 + amount))
    end
  end
  if promote_child_headlines then
    for _, headline in ipairs(self.headlines) do
      headline:promote(amount, true)
    end
  end
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
  local parsed_tags = utils.parse_tags_string(line:match(':.*:$'))
  for _, tag in ipairs(parsed_tags) do
    if not vim.tbl_contains(self.tags, tag) then
      table.insert(self.tags, tag)
    end
  end
  return parsed_tags
end

-- NOTE: Exclude dates from title if it appears in agenda on that day
function Headline:_parse_title(line, tags)
  local title = line
  for _, exclude_pattern in ipairs({ self.todo_keyword.value, vim.pesc(':'..table.concat(tags, ':')..':')..'$' }) do
    title = title:gsub(exclude_pattern, '')
  end
  self.title = vim.trim(title)
end

function Headline:get_category()
  if self.properties.items.CATEGORY then
    return self.properties.items.CATEGORY
  end
  return self.category
end

return Headline

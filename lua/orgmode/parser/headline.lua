local Headline = {}
local Types = require('orgmode.parser.types')
local Date = require('orgmode.objects.date')
local config = require('orgmode.config')

---@class Headline
---@param data table
function Headline:new(data)
  data = data or {}
  local headline = { type = Types.HEADLINE }
  headline.id = data.lnum
  headline.level = data.line and #data.line:match('^%*+') or 0
  headline.parent = data.parent.id
  headline.line = data.line
  headline.range = {
    from = { line = data.lnum, col = 1 },
    to = { line = data.lnum, col = 1 }
  }
  headline.content = {}
  headline.headlines = {}
  headline.todo_keyword = { value = '' }
  headline.priority = ''
  headline.title = ''
  headline.category = data.category or ''
  headline.dates = {}
  -- TODO: Add configuration for
  -- - org-use-tag-inheritance
  -- - org-tags-exclude-from-inheritance
  -- - org-tags-match-list-sublevels
  headline.tags = {}
  setmetatable(headline, self)
  self.__index = self
  headline:_parse_line()
  return headline
end

---@param headline Headline
---@return Headline
function Headline:add_headline(headline)
  table.insert(self.headlines, headline.id)
  return headline
end

---@return boolean
function Headline:is_done()
  return self.todo_keyword.value:upper() == 'DONE'
end

-- TODO: Check if this can be configured to be ignored
---@return boolean
function Headline:is_archived()
  return #vim.tbl_filter(function(tag) return tag:upper() == 'ARCHIVE' end, self.tags) > 0
    or self.category:upper() == 'ARCHIVE'
end

---@param content Content
---@return Content
function Headline:add_content(content)
  if content:is_planning() and vim.tbl_isempty(self.content) then
    for _, plan in ipairs(content.dates) do
      table.insert(self.dates, plan)
    end
  elseif content.dates then
    for _, date in ipairs(content.dates) do
      table.insert(self.dates, date:clone({ type = 'NONE' }))
    end
  end
  table.insert(self.content, content.id)
  return content
end

---@param lnum number
function Headline:set_range_end(lnum)
  self.range.to.line = lnum
end

---@return string
function Headline:tags_to_string()
  local tags = ''
  if #self.tags > 0 then
    tags = ':'..table.concat(self.tags, ':')..':'
  end
  return tags
end

function Headline:get_active_dates()
  return vim.tbl_filter(function(date)
    return date.active
  end, self.dates)
end

function Headline:_parse_line()
  local line = self.line
  line = line:gsub('^%*+%s+', '')

  self:_parse_todo_keyword()
  self.priority = line:match(self.todo_keyword.value..'%s+%[#([A-Z0-9])%]') or ''
  self:_parse_tags(line)
  self:_parse_title(line)
  local dates = Date.parse_all_from_line(self.line, self.range.from.line)
  for _, date in ipairs(dates) do
    table.insert(self.dates, date)
  end
end

function Headline:_parse_todo_keyword()
  for _, word in ipairs(config.org_todo_keywords) do
    local star = self.line:match('^%*+%s+')
    local keyword = self.line:match('^%*+%s+'..word..'%s+')
    -- If keyword doesn't have a space after it, check if whole line
    -- is just a keyword. For example: "* NEXT"
    if not keyword then
      keyword = self.line == star..word
    end
    if keyword then
      self.todo_keyword = {
        value = word,
        range = {
          from = { line = self.range.from.line, col = #star + 1 },
          to = { line = self.range.from.line, col = #star + #word },
        }
      }
      break
    end
  end
end

function Headline:_parse_tags(line)
  local tags = line:match(':.*:$') or ''
  if tags then
    for _, tag in ipairs(vim.split(tags, ':')) do
      if tag:find('^[%w_%%@#]+$') and not vim.tbl_contains(self.tags, tag) then
        table.insert(self.tags, tag)
      end
    end
  end
end

-- NOTE: Exclude dates from title if it appears in agenda on that day
function Headline:_parse_title(line)
  local title = line
  for _, exclude_pattern in ipairs({ self.todo_keyword.value, '%[#[A-Z0-9]%]', vim.pesc(':'..table.concat(self.tags, ':')..':')..'$' }) do
    title = title:gsub(exclude_pattern, '')
  end
  self.title = vim.trim(title)
end

return Headline

local Headline = {}
local Types = require('orgmode.parser.types')
local DateParser = require('orgmode.parser.date')
local config = require('orgmode.config')

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
  headline.todo_keyword = ''
  headline.priority = ''
  headline.title = ''
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

function Headline:add_headline(headline)
  table.insert(self.headlines, headline.id)
  return headline
end

function Headline:get_priority_date(date)
  local dates = {}
  for _, d in ipairs(self.dates) do
    if d:is_valid_for_agenda(date) then
      dates[d.type] = d
      if d:is_deadline(date) then
        break
      end
    end
  end
  if dates.DEADLINE then
    return dates.DEADLINE
  end
  if dates.SCHEDULED then
    return dates.SCHEDULED
  end

  return dates.NONE
end

function Headline:add_content(content)
  if content:is_planning() and vim.tbl_isempty(self.content) then
    for _, plan in ipairs(content.dates) do
      table.insert(self.dates, plan)
    end
  elseif content.dates then
    for _, date in ipairs(content.dates) do
      date.type = 'NONE'
      table.insert(self.dates, date)
    end
  end
  table.insert(self.content, content.id)
  return content
end

function Headline:set_range_end(lnum)
  self.range.to.line = lnum
end

function Headline:_parse_line()
  local line = self.line
  line = line:gsub('^%*+%s+', '')

  self:_parse_todo_keyword(line)
  self.priority = line:match(self.todo_keyword..'%s+%[#([A-Z0-9])%]') or ''
  self:_parse_tags(line)
  self:_parse_title(line)
  local dates = DateParser.parse_all_from_line(self.line, self.range.from.line)
  for _, date in ipairs(dates) do
    table.insert(self.dates, date)
  end
end

function Headline:_parse_todo_keyword(line)
  for _, word in ipairs(config.org_todo_keywords) do
    if vim.startswith(line, word) then
      self.todo_keyword = word
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
  for _, exclude_pattern in ipairs({ self.todo_keyword, '%[#[A-Z0-9]%]', vim.pesc(':'..table.concat(self.tags, ':')..':')..'$' }) do
    title = title:gsub(exclude_pattern, '')
  end
  self.title = vim.trim(title)
end

return Headline

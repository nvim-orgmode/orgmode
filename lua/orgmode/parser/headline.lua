local Headline = {}
local Types = require('orgmode.parser.types')
local todo_keywords = {'TODO', 'NEXT', 'DONE'}

function Headline:new(data)
  data = data or {}
  local headline = { type = Types.HEADLINE }
  headline.level = data.line and #data.line:match('^%*+') or 0
  headline.parent = data.parent.line_nr
  headline.line = data.line
  headline.line_nr = data.line_nr
  headline.content = {}
  headline.headlines = {}
  headline.todo_keyword = ''
  headline.priority = ''
  headline.title = ''
  -- TODO: Add configuration for
  -- - org-use-tag-inheritance
  -- - org-tags-exclude-from-inheritance
  -- - org-tags-match-list-sublevels
  headline.tags = {}
  setmetatable(headline, self)
  self.__index = self
  headline:parse_line()
  return headline
end

function Headline:add_headline(headline)
  table.insert(self.headlines, headline.line_nr)
  return headline
end

function Headline:add_content(content)
  table.insert(self.content, content.line_nr)
  return content
end

function Headline:parse_line()
  local line = self.line
  line = line:gsub('^%*+%s+', '')

  for _, word in ipairs(todo_keywords) do
    if vim.startswith(line, word) then
      self.todo_keyword = word
      break
    end
  end
  self.priority = line:match(self.todo_keyword..'%s+%[#([A-Z0-9])%]') or ''
  local tags = line:match(':.*:$') or ''
  if tags then
    for _, tag in ipairs(vim.split(tags, ':')) do
      if tag:find('^[%w_%%@#]+$') and not vim.tbl_contains(self.tags, tag) then
        table.insert(self.tags, tag)
      end
    end
  end
  local title = line
  for _, exclude_pattern in ipairs({ self.todo_keyword, '%[#[A-Z0-9]%]', vim.pesc(':'..table.concat(self.tags, ':')..':') }) do
    title = title:gsub(exclude_pattern, '')
  end
  self.title = vim.trim(title)
end

return Headline

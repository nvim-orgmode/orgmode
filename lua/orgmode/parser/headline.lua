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
  -- TODO: Add configuration for
  -- - org-use-tag-inheritance
  -- - org-tags-exclude-from-inheritance
  -- - org-tags-match-list-sublevels
  -- And add support for '#+FILETAGS'
  headline.tags = {unpack(data.parent.tags or {})}
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
  line = line:gsub('^%*+%s', '')
  for _, word in ipairs(todo_keywords) do
    if vim.startswith(line, word) then
      self.todo_keyword = word
      break
    end
  end
  local tags = line:match(':.*:$')
  if tags then
    for _, tag in ipairs(vim.split(tags, ':')) do
      if tag:find('^[%w_@]+$') and not vim.tbl_contains(self.tags, tag) then
        table.insert(self.tags, tag)
      end
    end
  end
end

return Headline

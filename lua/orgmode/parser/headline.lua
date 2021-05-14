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
  line = line:gsub('^%*+%s', '')
  for _, word in ipairs(todo_keywords) do
    if vim.startswith(line, word) then
      self.todo_keyword = word
      break
    end
  end
  local tags = line:match(':.*:$')
  if tags then
    self.tags = vim.tbl_filter(function(tag)
      return tag:find('^[%w_@]+$')
    end, vim.split(tags, ':'))
  end
end

return Headline

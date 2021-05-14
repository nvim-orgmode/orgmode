local Headline = {}
local Types = require('orgmode.parser.types')

function Headline:new(data)
  data = data or {}
  local headline = { type = Types.HEADLINE }
  headline.level = data.line and #data.line:match('^%*+') or 0
  headline.parent = data.parent.line_nr
  headline.line = data.line
  headline.line_nr = data.line_nr
  headline.content = {}
  headline.headlines = {}
  setmetatable(headline, self)
  self.__index = self
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

return Headline

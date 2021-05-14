local Headline = {}

function Headline:new(data)
  data = data or {}
  data.level = data.line and #data.line:match('^%*+') or 0
  data.parent = data.parent
  data.line = data.line
  data.content = {}
  data.headlines = {}
  setmetatable(data, self)
  self.__index = self
  return data
end

function Headline:add_headline(headline)
  table.insert(self.headlines, headline)
  return headline
end

function Headline:add_content(content)
  table.insert(self.content, content)
  return content
end

function Headline:get_parents_until(level)
  local parent = self.parent
  while parent.level > (level - 1) do
    parent = parent.parent
  end
  return parent
end

return Headline

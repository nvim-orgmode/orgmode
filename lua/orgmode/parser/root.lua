local Headline = require('orgmode.parser.headline')
local Content = require('orgmode.parser.content')
local Root = {}

function Root:new(lines)
  local data = {
    lines = lines,
    items = {},
    level = 0,
    line_nr = 0,
    parent = 0
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Root:add_headline(headline_data)
  local headline = Headline:new(headline_data)
  self.items[headline.line_nr] = headline
  local plevel = headline_data.parent.level
  if plevel > 0 and plevel < headline.level then
    headline_data.parent:add_headline(headline)
  end
  return headline
end

function Root:add_content(content_data)
  local content = Content:new(content_data)
  self.items[content.line_nr] = content
  if content_data.parent.level > 0 then
    content_data.parent:add_content(content)
  end
  return content
end

function Root:get_parents_until(headline, level)
  if headline.parent == 0 then
    return self
  end
  local parent = self.items[headline.parent]
  while parent.level > (level - 1) do
    if parent.parent == 0 then
      parent = self
      break
    end
    parent = self.items[parent.parent]
  end
  return parent
end

return Root

local Headline = require('orgmode.parser.headline')
local Content = require('orgmode.parser.content')
local Root = {}

function Root:new(lines)
  local data = {
    lines = lines,
    content = {},
    level = 0,
    line_nr = 0
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Root:add_headline(headline_data)
  local headline = Headline:new(headline_data)
  self.content[headline.line_nr] = headline
  local plevel = headline_data.parent.level
  if plevel > 0 and plevel < headline.level then
    headline_data.parent:add_headline(headline)
  end
  return headline
end

function Root:add_content(content_data)
  local content = Content:new(content_data)
  self.content[content.line_nr] = content
  if content_data.parent.level > 0 then
    content_data.parent:add_content(content)
  end
  return content
end

function Root:get_parents_until(headline, level)
  local parent = self.content[headline.parent]
  while parent.level > (level - 1) do
    if parent.parent == 0 then
      break
    end
    parent = self.content[parent.parent]
  end
  return parent
end

local function parse(lines)
  local root = Root:new(lines)
  local parent = root
  for line_nr, line in ipairs(lines) do
    local is_headline = line:match('^%*+%s')
    if is_headline then
      local level = #line:match('^%*+')
      if level < parent.level then
        parent = root:get_parents_until(parent, level)
      end
      parent = root:add_headline({ line = line, line_nr = line_nr, parent = parent })
    else
      root:add_content({ line = line, line_nr = line_nr, parent = parent })
    end
  end
  return root
end

return {
  parse = parse
}

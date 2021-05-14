local Headline = require('orgmode.parser.headline')
local Content = require('orgmode.parser.content')

local function parse(lines)
  local root = Headline:new()
  local parent = root
  for _, line in ipairs(lines) do
    local is_headline = line:match('^%*+%s')
    if is_headline then
      local level = #line:match('^%*+')
      if level < parent.level then
        parent = parent:get_parents_until(level)
      end
      local headline = parent:add_headline(Headline:new({ line = line, parent = parent }))
      parent = headline
    else
      parent:add_content(Content:new({ line = line, parent = parent }))
    end
  end
  return root
end

return {
  parse = parse
}

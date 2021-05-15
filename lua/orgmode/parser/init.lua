local Root = require('orgmode.parser.root')

local function parse(lines)
  local root = Root:new(lines)
  local parent = root
  for lnum, line in ipairs(lines) do
    local is_headline = line:match('^%*+%s+')
    if is_headline then
      local level = #line:match('^%*+')
      if level <= parent.level then
        root:set_headline_end(parent, lnum, level)
        parent = root:get_parent_for_level(parent, level)
      end
      parent = root:add_headline({ line = line, lnum = lnum, parent = parent })
    else
      root:add_content({ line = line, lnum = lnum, parent = parent })
    end
  end
  return root
end

return {
  parse = parse
}

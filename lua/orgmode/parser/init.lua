local Root = require('orgmode.parser.root')

local function parse(lines)
  local root = Root:new(lines)
  local parent = root
  for line_nr, line in ipairs(lines) do
    local is_headline = line:match('^%*+%s')
    if is_headline then
      local level = #line:match('^%*+')
      if level <= parent.level then
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

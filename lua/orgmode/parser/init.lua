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
      if lnum == #lines and parent.level > 0 then
        root:set_headline_end(parent, lnum, 1)
      end
    end
  end
  return root:finish_parsing()
end

return {
  parse = parse
}

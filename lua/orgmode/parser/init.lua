local Root = require('orgmode.parser.root')
local Content = require('orgmode.parser.content')

---@param lines string[]
---@param category string
---@param file string
---@return Root
local function parse(lines, category, file)
  local root = Root:new(lines, category, file)
  local parent = root
  local parent_content = nil
  for lnum, line in ipairs(lines) do
    local is_headline = line:match('^%*+%s+')
    if is_headline then
      parent_content = nil
      local level = #line:match('^%*+')
      if level <= parent.level then
        root:set_headline_end(parent, lnum, level)
        parent = root:get_parent_for_level(parent, level)
      end
      parent = root:add_headline({ line = line, lnum = lnum, parent = parent })
    else
      local content = Content:new({  line = line, lnum = lnum, parent = parent })
      if parent_content then
        parent_content:add_content(content)
      end
      root:add_content(content, parent, parent_content)

      if content:is_parent_start() then
        parent_content = content
      end

      if content:is_parent_end() then
        parent_content = nil
      end

      if lnum == #lines and parent.level > 0 then
        root:set_headline_end(parent, lnum, 1)
      end
    end
  end
  return root
end

return {
  parse = parse
}

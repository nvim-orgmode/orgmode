local Root = require('orgmode.parser.root')

---@param lines string[]
---@param category string
---@param file string
---@param is_archive_file boolean
---@return Root
local function parse(lines, category, file, is_archive_file)
  local root = Root:new(lines, category, file, is_archive_file)
  local parent = root
  for lnum, line in ipairs(lines) do
    local is_headline = line:match('^%*+%s+')
    if is_headline then
      local level = #line:match('^%*+')
      if level <= parent.level then
        root:set_headline_end(parent, lnum - 1, level)
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
  return root
end

return {
  parse = parse
}

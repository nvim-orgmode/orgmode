local tree_utils = require('orgmode.utils.treesitter')
local Headline = require('orgmode.treesitter.headline')
local Listitem = require('orgmode.treesitter.listitem')

---@param cursor? Table Cursor position tuple {row, col}
---@return Headline
local function closest_headline(cursor)
  local ts_headline = Headline.from_cursor(cursor)
  if not ts_headline then
    error('Unable to locate closest headline')
  end
  return ts_headline
end

local function listitem()
  vim.treesitter.get_parser(0, 'org', {}):parse()
  local list_item = tree_utils.find_parent_type(tree_utils.current_node(), 'listitem')
  if list_item then
    return Listitem:new(list_item)
  end
  return nil
end

---@param title string
---@param exact? boolean
local function find_headline(title, exact)
  local trees = vim.treesitter.get_parser(0, 'org', {}):parse()
  if #trees == 0 then
    return nil
  end
  local root = trees[1]:root()
  local ts_query = tree_utils.parse_query('(section (headline) @headline)')
  for _, match, _ in ts_query:iter_matches(root) do
    -- local items = {}
    for _, matched_node in pairs(match) do
      local headline = Headline:new(matched_node)
      local pattern = '^' .. vim.pesc(title:lower())
      if exact then
        pattern = pattern .. '$'
      end

      if headline:title():lower():match(pattern) then
        return headline
      end
    end
  end
end

return {
  closest_headline = closest_headline,
  listitem = listitem,
  find_headline = find_headline,
}

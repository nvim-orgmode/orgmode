local tree_utils = require('orgmode.utils.treesitter')
local Headline = require('orgmode.treesitter.headline')
local Listitem = require('orgmode.treesitter.listitem')

---@return Headline
local function closest_headline()
  local ts_headline = tree_utils.closest_headline()
  if not ts_headline then
    error('Unable to locate closest headline')
  end
  return Headline:new(ts_headline)
end

local function listitem()
  vim.treesitter.get_parser(0, 'org', {}):parse()
  local list_item = tree_utils.find_parent_type(tree_utils.current_node(), 'listitem')
  if list_item then
    return Listitem:new(list_item)
  end
  return nil
end

return {
  closest_headline = closest_headline,
  listitem = listitem,
}

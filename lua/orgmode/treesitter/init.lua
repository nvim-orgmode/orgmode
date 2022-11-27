local tree_utils = require('orgmode.utils.treesitter')
local Headline = require('orgmode.treesitter.headline')
local Listitem = require('orgmode.treesitter.listitem')
local M = {}

---@param matcher function
---@return Headline|nil
local function query_headlines(matcher)
  local trees = vim.treesitter.get_parser(0, 'org', {}):parse()
  if #trees == 0 then
    return {}
  end
  local root = trees[1]:root()
  local ts_query = tree_utils.parse_query('(section (headline) @headline)')
  local index = 1
  for _, match, _ in ts_query:iter_matches(root) do
    -- local items = {}
    for _, matched_node in pairs(match) do
      local headline = Headline:new(matched_node)
      local valid = matcher(headline, index)
      if valid then
        return headline
      end
      index = index + 1
    end
  end
end

---@param cursor? Table Cursor position tuple {row, col}
---@return Headline
M.closest_headline = function(cursor)
  local ts_headline = Headline.from_cursor(cursor)
  if not ts_headline then
    error('Unable to locate closest headline')
  end
  return ts_headline
end

---@return Listitem|nil
M.listitem = function()
  vim.treesitter.get_parser(0, 'org', {}):parse()
  local list_item = tree_utils.find_parent_type(tree_utils.current_node(), 'listitem')
  if list_item then
    return Listitem:new(list_item)
  end
  return nil
end

---@return Headline|nil
M.headline_at = function(index)
  return query_headlines(function(_, i)
    return i == index
  end)
end

---@param title string
---@param exact? boolean
---@return Headline|nil
M.find_headline_by_title = function(title, exact)
  return query_headlines(function(headline, _)
    local pattern = '^' .. vim.pesc(title:lower())
    if exact then
      pattern = pattern .. '$'
    end

    return headline:title():lower():match(pattern)
  end)
end

return M

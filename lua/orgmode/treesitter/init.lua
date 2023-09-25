local tree_utils = require('orgmode.utils.treesitter')
local ts = require('orgmode.treesitter.compat')
local ts_utils = require('nvim-treesitter.ts_utils')
local Headline = require('orgmode.treesitter.headline')
local Listitem = require('orgmode.treesitter.listitem')
local M = {}

---@param matcher function(headline: Headline, index: number): boolean
---@param from_end? boolean
---@return Headline|nil
local function query_headlines(matcher, from_end)
  local trees = vim.treesitter.get_parser(0, 'org', {}):parse()
  if #trees == 0 then
    return {}
  end
  local root = trees[1]:root()
  local ts_query = tree_utils.parse_query('(section (headline) @headline)')
  local headlines = {}
  for _, match, _ in ts_query:iter_matches(root) do
    for _, matched_node in pairs(match) do
      local headline = Headline:new(matched_node)
      table.insert(headlines, headline)
    end
  end

  if from_end then
    for i = #headlines, 1, -1 do
      local headline = headlines[i]
      local valid = matcher(headline, i)
      if valid then
        return headline
      end
    end
    return nil
  end

  for i, headline in ipairs(headlines) do
    local valid = matcher(headline, i)
    if valid then
      return headline
    end
  end

  return nil
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

---@class FindHeadlineOpts
---@field from_end? boolean
---@field exact? boolean

---@param title string
---@param opts? FindHeadlineOpts
---@return Headline|nil
M.find_headline_by_title = function(title, opts)
  opts = opts or {}
  return query_headlines(function(headline, _)
    local pattern = '^' .. vim.pesc(title:lower())
    if opts.exact then
      pattern = pattern .. '$'
    end

    return headline:title():lower():match(pattern)
  end, opts.from_end)
end

local function parse_header_args(args)
  local properties = {}

  local property_value = ''
  local property_name

  local add_property = function()
    if property_name then
      properties[property_name:sub(2)] = vim.trim(property_value)
    end
  end

  for _, param in ipairs(args) do
    if param:sub(1, 1) == ':' then
      add_property()
      property_name = param:lower()
      property_value = ''
    else
      property_value = property_value .. ' ' .. param
    end
  end
  add_property()

  return properties
end

local function get_section_properties(root)
  local properties_node
  for _, node in ipairs(ts_utils.get_named_children(root)) do
    if node:type() == 'property_drawer' then
      properties_node = node
      break
    end
  end

  if not properties_node then
    return {}
  end

  local properties = {}
  for _, node in ipairs(ts_utils.get_named_children(properties_node)) do
    local name = node:field('name')[1]
    local value = node:field('value')[1]
    local property_name = name and ts.get_node_text(name, 0):lower()
    local property_value = value and ts.get_node_text(value, 0) or ''

    if property_name then
      if property_name == 'header-args' then
        local args = vim.split(property_value, ' ')
        properties = vim.tbl_deep_extend('keep', properties, parse_header_args(args))
      elseif not properties[property_name] then
        properties[property_name] = property_value
      end
    end
  end
  return properties
end

local function get_block_properties(root)
  local params = {}
  for _, node in ipairs(root:field('parameter')) do
    table.insert(params, ts.get_node_text(node, 0))
  end

  return parse_header_args(params)
end

local function get_document_properties(root)
  local body = root:field('body')[1]
  local directives = body and body:field('directive')

  if not directives then
    return {}
  end

  local properties = {}
  for _, node in ipairs(directives) do
    local value = node:field('value')[1]
    if value then
      local directive = ts.get_node_text(value, 0):lower()
      local args = vim.split(directive, ' ')

      local property_name = args[1]
      table.remove(args, 1)

      if property_name == 'header-args' then
        properties = vim.tbl_deep_extend('force', properties, parse_header_args(args))
      end
    end
  end
  return properties
end

M.get_node_properties = function(node)
  local properties = {}

  while node do
    local type = node:type()
    if type == 'section' then
      properties = vim.tbl_deep_extend('keep', properties, get_section_properties(node))
    elseif type == 'block' then
      properties = vim.tbl_deep_extend('force', properties, get_block_properties(node))
    elseif type == 'document' then
      properties = vim.tbl_deep_extend('keep', properties, get_document_properties(node))
    end
    node = node:parent()
  end

  return properties
end

M.get_properties_at = function(cursor)
  cursor = cursor or vim.api.nvim_win_get_cursor(0)
  local node = tree_utils.get_node_at_cursor(cursor)
  return M.get_node_properties(node)
end

return M

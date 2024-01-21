local ts_utils = require('nvim-treesitter.ts_utils')
local parsers = require('nvim-treesitter.parsers')
local M = {}
local query_cache = {}

function M.current_node()
  local window = vim.api.nvim_get_current_win()
  return ts_utils.get_node_at_cursor(window)
end

function M.parse(bufnr)
  return vim.treesitter.get_parser(bufnr or 0, 'org', {}):parse()
end

-- Reload treesitter highlighter without triggering FileType autocommands that include reloading entire file
function M.restart_highlights(bufnr)
  bufnr = bufnr or 0
  require('nvim-treesitter.configs').reattach_module('highlight', bufnr, 'org')
end

function M.parse_query(query)
  local ts_query = query_cache[query]
  if not ts_query then
    ts_query = vim.treesitter.query.parse('org', query)
    query_cache[query] = ts_query
  end
  return query_cache[query]
end

---This is a full copy of nvim_treesiter get_node_at_cursor with support for custom cursor position
---@param cursor? Table Cursor position tuple {row, col}
---@param winnr? number
---@param ignore_injected_langs? boolean
function M.get_node_at_cursor(cursor, winnr, ignore_injected_langs)
  if not cursor then
    return ts_utils.get_node_at_cursor(winnr, ignore_injected_langs)
  end

  winnr = winnr or 0
  local buf = vim.api.nvim_win_get_buf(winnr)
  -- TODO: Use only this function when 0.8 is released
  if vim.treesitter.get_node then
    return vim.treesitter.get_node({
      bufrn = buf,
      pos = { cursor[1] - 1, cursor[2] },
      ignore_injections = ignore_injected_langs,
    })
  end

  local cursor_range = { cursor[1] - 1, cursor[2] }

  local root_lang_tree = parsers.get_parser(buf)
  if not root_lang_tree then
    return
  end

  local root
  if ignore_injected_langs then
    for _, tree in ipairs(root_lang_tree:trees()) do
      local tree_root = tree:root()
      if tree_root and ts_utils.is_in_node_range(tree_root, cursor_range[1], cursor_range[2]) then
        root = tree_root
        break
      end
    end
  else
    root = ts_utils.get_root_for_position(cursor_range[1], cursor_range[2], root_lang_tree)
  end

  if not root then
    return
  end

  return root:named_descendant_for_range(cursor_range[1], cursor_range[2], cursor_range[1], cursor_range[2])
end

-- walks the tree to find a headline
function M.find_headline(node)
  if node:type() == 'headline' then
    return node
  elseif node:type() == 'section' then
    -- The headline is always the first child of a section
    return ts_utils.get_named_children(node)[1]
  elseif node:parent() then
    return M.find_headline(node:parent())
  else
    return nil
  end
end

-- returns the nearest headline
function M.closest_headline(cursor)
  vim.treesitter.get_parser(0, 'org', {}):parse()
  return M.find_headline(M.get_node_at_cursor(cursor))
end

function M.find_parent_type(node, type)
  if node:type() == type then
    return node
  end
  if node:type() == 'body' then
    return nil
  end
  return M.find_parent_type(node:parent(), type)
end

-- @param front_trim boolean
function M.set_node_text(node, text, front_trim)
  local lines = vim.split(text, '\n', true)
  local sr, sc, er, ec = node:range()
  if string.len(text) == 0 then
    if front_trim then
      sc = math.max(sc - 1, 0)
    else
      ec = ec + 1
    end
  end
  pcall(vim.api.nvim_buf_set_text, 0, sr, sc, er, ec, lines)
end

---@param node TSNode
---@param lines string[]
function M.set_node_lines(node, lines)
  local start_row, _, end_row, _ = node:range()
  vim.api.nvim_buf_set_lines(0, start_row, end_row, false, lines)
end

return M

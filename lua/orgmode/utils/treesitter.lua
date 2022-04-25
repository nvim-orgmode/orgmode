local ts_utils = require('nvim-treesitter.ts_utils')
local config = require('orgmode.config')
local M = {}

-- Searches headline item nodes for a match
local function parse_item(headline, pattern)
  local matching_nodes = vim.tbl_filter(function(node)
    local text = vim.treesitter.query.get_node_text(node, 0) or ''
    return string.match(text, pattern)
  end, ts_utils.get_named_children(headline:field('item')[1]))
  return matching_nodes[1]
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
function M.closest_headline()
  vim.treesitter.get_parser(0, 'org'):parse()
  return M.find_headline(ts_utils.get_node_at_cursor(vim.api.nvim_get_current_win()))
end

function M.get_priority(headline)
  return parse_item(headline, '%[#%w+%]')
end

function M.get_todo(headline)
  local keywords = config.todo_keywords.ALL
  local todos = {}
  for _, word in ipairs(keywords) do
    local todo = parse_item(headline, string.gsub(word, '-', '%%-'))
    if todo then
      table.insert(todos, todo)
    end
  end
  return todos[1]
end

function M.get_stars(headline)
  return headline:field('stars')[1]
end

function M.set_node_text(node, text)
  local sr, sc, er, ec = node:range()
  if string.len(text) == 0 then
    ec = ec + 1
  end
  vim.api.nvim_buf_set_text(0, sr, sc, er, ec, { text })
end

function M.set_priority(headline, priority)
  local current_priority = M.get_priority(headline)
  if current_priority then
    local text = (vim.trim(priority) == '') and '' or string.format('[#%s]', priority)
    M.set_node_text(current_priority, text)
  else
    local todo = M.get_todo(headline)
    if todo then
      local text = vim.treesitter.query.get_node_text(todo, 0)
      M.set_node_text(todo, string.format('%s [#%s]', text, priority))
    else
      local stars = M.get_stars(headline)
      local text = vim.treesitter.query.get_node_text(stars, 0)
      M.set_node_text(stars, string.format('%s [#%s]', text, priority))
    end
  end
end

return M

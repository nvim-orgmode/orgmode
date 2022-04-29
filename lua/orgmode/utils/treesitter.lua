local ts_utils = require('nvim-treesitter.ts_utils')
local config = require('orgmode.config')
local M = {}

-- Searches headline item nodes for a match
local function parse_item(headline, pattern)
  local match = ''
  local matching_nodes = vim.tbl_filter(function(node)
    local text = vim.treesitter.query.get_node_text(node, 0) or ''
    local m = string.match(text, pattern)
    if m then
      match = string.match(text, pattern)
      return true
    end
  end, ts_utils.get_named_children(headline:field('item')[1]))
  return matching_nodes[1], match
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
  return parse_item(headline, '%[#(%w+)%]')
end

-- Returns the headlines todo node, it's keyword,
-- and if it's in done state
-- @return Node, string, boolean
function M.get_todo(headline)
  local keywords = config.todo_keywords.ALL
  local done_keywords = config.todo_keywords.DONE
  for _, word in ipairs(keywords) do
    local todo = parse_item(headline, string.gsub(word, '-', '%%-'))
    if todo then
      return todo, word, vim.tbl_contains(done_keywords, word)
    end
  end
end

function M.get_stars(headline)
  return headline:field('stars')[1]
end

-- @param front_trim boolean
function M.set_node_text(node, text, front_trim)
  local sr, sc, er, ec = node:range()
  if string.len(text) == 0 then
    if front_trim then
      sc = sc - 1
    else
      ec = ec + 1
    end
  end
  vim.api.nvim_buf_set_text(0, sr, sc, er, ec, { text })
end

function M.set_priority(headline, priority)
  local current_priority = M.get_priority(headline)
  if current_priority then
    local text = (vim.trim(priority) == '') and '' or string.format('[#%s]', priority)
    M.set_node_text(current_priority, text)
    return
  end

  local todo = M.get_todo(headline)
  if todo then
    local text = vim.treesitter.query.get_node_text(todo, 0)
    M.set_node_text(todo, string.format('%s [#%s]', text, priority))
    return
  end

  local stars = M.get_stars(headline)
  local text = vim.treesitter.query.get_node_text(stars, 0)
  M.set_node_text(stars, string.format('%s [#%s]', text, priority))
end

function M.set_todo(headline, keyword)
  local current_todo = M.get_todo(headline)
  if current_todo then
    M.set_node_text(current_todo, keyword)
    return
  end

  local stars = M.get_stars(headline)
  local text = vim.treesitter.query.get_node_text(stars, 0)
  M.set_node_text(stars, string.format('%s %s', text, keyword))
end

function M.get_plan(headline)
  local section = headline:parent()
  for _, node in ipairs(ts_utils.get_named_children(section)) do
    if node:type() == 'plan' then
      return node
    end
  end
end

function M.get_dates(headline)
  local plan = M.get_plan(headline)
  local dates = {}
  for _, node in ipairs(ts_utils.get_named_children(plan)) do
    local name = vim.treesitter.query.get_node_text(node:named_child(0), 0)
    dates[name] = node
  end
  return dates
end

function M.repeater_dates(headline)
  return vim.tbl_filter(function(entry)
    local timestamp = entry:field('timestamp')[1]
    for _, node in ipairs(ts_utils.get_named_children(timestamp)) do
      if node:type() == 'repeat' then
        return true
      end
    end
  end, M.get_dates(headline))
end

function M.add_closed_date(headline)
  local dates = M.get_dates(headline)
  if vim.tbl_count(dates) == 0 or dates['CLOSED'] then
    return
  end
  local last_child = dates['DEADLINE'] or dates['SCHEDULED']
  local ptext = vim.treesitter.query.get_node_text(last_child, 0)
  local text = ptext .. ' CLOSED: [' .. vim.fn.strftime('%Y-%m-%d %a %H:%M') .. ']'
  M.set_node_text(last_child, text)
end

function M.remove_closed_date(headline)
  local dates = M.get_dates(headline)
  if vim.tbl_count(dates) == 0 or not dates['CLOSED'] then
    return
  end
  M.set_node_text(dates['CLOSED'], '', true)
end

return M

local ts_utils = require('nvim-treesitter.ts_utils')
local tree_utils = require('orgmode.utils.treesitter')
local Date = require('orgmode.objects.date')
local config = require('orgmode.config')
local query = vim.treesitter.query

local Headline = {}

---@param headline_node userdata tree sitter headline node
function Headline:new(headline_node)
  local data = { headline = headline_node }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Headline:stars()
  return self.headline:field('stars')[1]
end

---@return number
function Headline:level()
  local stars = self:stars()
  return query.get_node_text(stars, 0):len()
end

function Headline:priority()
  return self:parse('%[#(%w+)%]')
end

function Headline:set_priority(priority)
  local current_priority = self:priority()
  if current_priority then
    local text = (vim.trim(priority) == '') and '' or ('[#%s]'):format(priority)
    tree_utils.set_node_text(current_priority, text)
    return
  end

  local todo = self:todo()
  if todo then
    local text = query.get_node_text(todo, 0)
    tree_utils.set_node_text(todo, ('%s [#%s]'):format(text, priority))
    return
  end

  local stars = self:stars()
  local text = query.get_node_text(stars, 0)
  tree_utils.set_node_text(stars, ('%s [#%s]'):format(text, priority))
end

function Headline:set_todo(keyword)
  local current_todo = self:todo()
  if current_todo then
    tree_utils.set_node_text(current_todo, keyword)
    return
  end

  local stars = self:stars()
  local text = query.get_node_text(stars, 0)
  tree_utils.set_node_text(stars, string.format('%s %s', text, keyword))
end

function Headline:item()
  return self.headline:field('item')[1]
end

-- Returns the headlines todo node, it's keyword,
-- and if it's in done state
-- @return Node, string, boolean
function Headline:todo()
  local keywords = config.todo_keywords.ALL
  local done_keywords = config.todo_keywords.DONE
  for _, word in ipairs(keywords) do
    local todo = self:parse(word:gsub('-', '%%-'))
    if todo then
      return todo, word, vim.tbl_contains(done_keywords, word)
    end
  end
end

function Headline:plan()
  local section = self.headline:parent()
  for _, node in ipairs(ts_utils.get_named_children(section)) do
    if node:type() == 'plan' then
      return node
    end
  end
end

function Headline:dates()
  local plan = self:plan()
  local dates = {}

  if not plan then
    return dates
  end

  for _, node in ipairs(ts_utils.get_named_children(plan)) do
    local name = vim.treesitter.query.get_node_text(node:named_child(0), 0)
    dates[name] = node
  end
  return dates
end

function Headline:repeater_dates()
  return vim.tbl_filter(function(entry)
    local timestamp = entry:field('timestamp')[1]
    for _, node in ipairs(ts_utils.get_named_children(timestamp)) do
      if node:type() == 'repeat' then
        return true
      end
    end
  end, self:dates())
end

function Headline:add_closed_date()
  local dates = self:dates()
  if dates['CLOSED'] then
    return
  end
  local closed_text = 'CLOSED: ' .. Date.now():to_wrapped_string(false)
  if vim.tbl_isempty(dates) then
    local indent = config:get_indent(self:level() + 1)
    local start_line = self.headline:start()
    return vim.api.nvim_call_function('append', {
      start_line + 1,
      string.format('%s%s', indent, closed_text),
    })
  end
  local last_child = dates['DEADLINE'] or dates['SCHEDULED']
  local ptext = query.get_node_text(last_child, 0)
  local text = ptext .. ' ' .. closed_text
  tree_utils.set_node_text(last_child, text)
end

function Headline:remove_closed_date()
  local dates = self:dates()
  if vim.tbl_count(dates) == 0 or not dates['CLOSED'] then
    return
  end
  local line_nr = dates['CLOSED']:start() + 1
  tree_utils.set_node_text(dates['CLOSED'], '', true)
  if vim.trim(vim.fn.getline(line_nr)) == '' then
    return vim.api.nvim_call_function('deletebufline', { vim.api.nvim_get_current_buf(), line_nr })
  end
end

-- @return tsnode, string
function Headline:parse(pattern)
  local match = ''
  local matching_nodes = vim.tbl_filter(function(node)
    local text = query.get_node_text(node, 0) or ''
    local m = text:match(pattern)
    if m then
      match = text:match(pattern)
      return true
    end
  end, ts_utils.get_named_children(self:item()))
  return matching_nodes[1], match
end

return Headline

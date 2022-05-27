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

function Headline:tags()
  local node = self.headline:field('tags')[1]
  local text = ''
  if node then
    text = query.get_node_text(node, 0)
  end
  return node, text
end

function Headline:set_tags(tags)
  local predecessor = nil
  for _, node in ipairs(ts_utils.get_named_children(self.headline)) do
    if node:type() ~= 'tag_list' then
      predecessor = node
    end
  end

  local pred_end_row, pred_end_col, _ = predecessor:end_()
  local end_col = vim.api.nvim_strwidth(vim.fn.getline(pred_end_row + 1))

  local text = ''
  tags = vim.trim(tags):gsub('^:', ''):gsub(':$', '')
  if tags ~= '' then
    tags = ':' .. tags .. ':'

    local to_col = config.org_tags_column
    if to_col < 0 then
      local tags_width = vim.api.nvim_strwidth(tags)
      to_col = math.abs(to_col) - tags_width
    end

    local spaces = math.max(to_col - pred_end_col, 1)
    text = string.rep(' ', spaces) .. tags
  end

  vim.api.nvim_buf_set_text(0, pred_end_row, pred_end_col, pred_end_row, end_col, { text })
end

function Headline:align_tags()
  local current_tags, current_text = self:tags()
  if current_tags then
    self:set_tags(current_text)
  end
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

  -- A valid keyword can only be the first child
  local todo_node = self:item():named_child(0)
  if not todo_node then
    return nil
  end

  local text = query.get_node_text(todo_node, 0)
  for _, word in ipairs(keywords) do
    -- there may be multiple substitutions necessary
    escaped_word = vim.pesc(word)
    local todo = text:match(escaped_word)
    if todo then
      return todo_node, word, vim.tbl_contains(done_keywords, word)
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
    local name = query.get_node_text(node:named_child(0), 0)
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

function Headline:cookie()
  local cookie = self:parse('%[%d*/%d*%]')
  if cookie then
    return cookie
  end
  return self:parse('%[%d?%d?%d?%%%]')
end

function Headline:update_cookie(list_node)
  local total_boxes = self:child_checkboxes(list_node)
  local checked_boxes = vim.tbl_filter(function(box)
    return box:match('%[%w%]')
  end, total_boxes)

  local cookie = self:cookie()
  if cookie then
    local new_cookie_val
    if query.get_node_text(cookie, 0):find('%%') then
      new_cookie_val = ('[%d%%]'):format((#checked_boxes / #total_boxes) * 100)
    else
      new_cookie_val = ('[%d/%d]'):format(#checked_boxes, #total_boxes)
    end
    tree_utils.set_node_text(cookie, new_cookie_val)
  end
end

function Headline:child_checkboxes(list_node)
  return vim.tbl_map(function(node)
    local text = query.get_node_text(node, 0)
    return text:match('%[.%]')
  end, ts_utils.get_named_children(list_node))
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

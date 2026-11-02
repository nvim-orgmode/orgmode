local ts_utils = require('orgmode.utils.treesitter')

---@class OrgListitem
---@field listitem TSNode
---@field file OrgFile
local Listitem = {}

---@return OrgListitem
function Listitem:new(listitem_node, file)
  local data = {
    listitem = listitem_node,
    file = file,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Listitem:get_new_checkbox_value(action, current_value, total_child_checkboxes, checked_child_checkboxes)
  if action == 'on' then
    return '[X]'
  elseif action == 'off' then
    return '[ ]'
  elseif action == 'toggle' then
    return (current_value == '[X]' or current_value == '[x]') and '[ ]' or '[X]'
  elseif action == 'children' then
    if #checked_child_checkboxes == 0 then
      return '[ ]'
    elseif #checked_child_checkboxes == #total_child_checkboxes then
      return '[X]'
    end
  end
  return '[-]'
end

function Listitem:checkbox()
  local checkbox = self.listitem:field('checkbox')[1]
  if not checkbox then
    return nil
  end
  local text = self.file:get_node_text(checkbox)
  return { text = text, range = { checkbox:range() } }
end

function Listitem:update_checkbox(action)
  action = action or 'toggle'

  local checkbox = self:checkbox()
  local total_child_checkboxes = self:child_checkboxes() or {}
  local checked_child_checkboxes = vim.tbl_filter(function(box)
    return box:match('%[%w%]')
  end, total_child_checkboxes)

  if checkbox then
    vim.api.nvim_buf_set_text(
      0,
      checkbox.range[1],
      checkbox.range[2],
      checkbox.range[3],
      checkbox.range[4],
      { self:get_new_checkbox_value(action, checkbox.text, total_child_checkboxes, checked_child_checkboxes) }
    )
  end

  self:update_cookie(total_child_checkboxes, checked_child_checkboxes)

  local parent_list = ts_utils.closest_node(self.listitem, 'list')
  local parent_listitem = ts_utils.closest_node(parent_list, 'listitem')
  if parent_listitem then
    Listitem:new(parent_listitem, self.file):update_checkbox('children')
  else
    local parent_headline = self.file:get_closest_headline_or_nil()
    if parent_headline then
      parent_headline:update_cookie()
    end
  end
end

function Listitem:child_checkboxes()
  local contents = self.listitem:field('contents')
  for _, content in ipairs(contents) do
    if content:type() == 'list' then
      return vim.tbl_map(function(node)
        local text = self.file:get_node_text(node)
        return text:match('%[.%]')
      end, ts_utils.get_named_children(content))
    end
  end
end

function Listitem:cookie()
  local content = self.listitem:field('contents')[1]
  -- The cookie should be the last thing on the line
  local cookie_node = content:named_child(content:named_child_count() - 1)
  if not cookie_node then
    return nil
  end

  local text = self.file:get_node_text(cookie_node)
  if text:match('%[%d*/%d*%]') or text:match('%[%d?%d?%d?%%%]') then
    return cookie_node
  end
end

function Listitem:update_cookie(total_child_checkboxes, checked_child_checkboxes)
  local cookie = self:cookie()
  if cookie then
    local new_cookie_val
    if self.file:get_node_text(cookie):find('%%') then
      new_cookie_val = ('[%d%%]'):format((#checked_child_checkboxes / #total_child_checkboxes) * 100)
    else
      new_cookie_val = ('[%d/%d]'):format(#checked_child_checkboxes, #total_child_checkboxes)
    end
    self.file:set_node_text(cookie, new_cookie_val)
  end
end

---@param line string
---@return string
function Listitem._increase(line)
  return '  ' .. line
end
---
---@param line string
---@return string
function Listitem._decrease(line)
  local repl, _ = line:gsub('^  ', '', 1)
  return repl
end

---@param adjust_fn function
---@param include_childs boolean
function Listitem:_adjust_lines(adjust_fn, include_childs)
  local start_row, _, end_row, _ = self.listitem:range()
  if not include_childs then
    end_row = start_row + 1
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row, false)
  for i, line in ipairs(lines) do
    lines[i] = adjust_fn(line)
  end
  vim.api.nvim_buf_set_lines(0, start_row, end_row, false, lines)
end

---@param include_childs boolean
function Listitem:demote(include_childs)
  self:_adjust_lines(self._increase, include_childs)
end

---@param include_childs boolean
function Listitem:promote(include_childs)
  self:_adjust_lines(self._decrease, include_childs)
end

---@private
---@return number start_row 0-based
---@return number end_row 0-based, exclusive
function Listitem:_line_range()
  local start_row, _, end_row, end_col = self.listitem:range()
  -- For last item in file, ts grammar is not parsing the end column as 0
  if end_col ~= 0 then
    end_row = end_row + 1
  end
  return start_row, end_row
end

---Swap the list item, together with its children, with the previous or next item in the same list.
---Numbers of an ordered list stay in place.
---@param direction 'up' | 'down'
---@return number | nil offset Number of lines the item moved by, nil if there is no item to swap with
function Listitem:move(direction)
  local sibling
  if direction == 'up' then
    sibling = self.listitem:prev_named_sibling()
  else
    sibling = self.listitem:next_named_sibling()
  end
  if not sibling or sibling:type() ~= 'listitem' then
    return nil
  end
  local first, second = self, Listitem:new(sibling, self.file)
  if direction == 'up' then
    first, second = second, first
  end
  local first_start, first_end = first:_line_range()
  local second_start, second_end = second:_line_range()

  local first_lines = vim.api.nvim_buf_get_lines(0, first_start, first_end, false)
  local gap = vim.api.nvim_buf_get_lines(0, first_end, second_start, false)
  local second_lines = vim.api.nvim_buf_get_lines(0, second_start, second_end, false)

  local first_bullet = first_lines[1]:match('^%s*%d+[.)]')
  local second_bullet = second_lines[1]:match('^%s*%d+[.)]')
  if first_bullet and second_bullet then
    first_lines[1] = second_bullet .. first_lines[1]:sub(#first_bullet + 1)
    second_lines[1] = first_bullet .. second_lines[1]:sub(#second_bullet + 1)
  end

  local lines = vim.list_extend(vim.list_extend(second_lines, gap), first_lines)
  vim.api.nvim_buf_set_lines(0, first_start, second_end, false, lines)

  if direction == 'up' then
    return first_start - second_start
  end
  return second_end - first_end
end

return Listitem

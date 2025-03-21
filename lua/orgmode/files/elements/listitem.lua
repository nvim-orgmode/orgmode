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

return Listitem

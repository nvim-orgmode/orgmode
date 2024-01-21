local ts_utils = require('nvim-treesitter.ts_utils')
local tree_utils = require('orgmode.utils.treesitter')
local ts = vim.treesitter
local Headline = require('orgmode.treesitter.headline')

---@class Listitem
---@field listitem TSNode
local Listitem = {}

function Listitem:new(listitem_node)
  local data = { listitem = listitem_node }
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
  local text = ts.get_node_text(checkbox, 0)
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

  local parent_list = tree_utils.find_parent_type(self.listitem, 'list')
  local parent_listitem = tree_utils.find_parent_type(parent_list, 'listitem')
  if parent_listitem then
    Listitem:new(parent_listitem):update_checkbox('children')
  else
    local parent_headline = tree_utils.closest_headline()
    if parent_headline then
      Headline:new(parent_headline):update_cookie(parent_list)
    end
  end
end

function Listitem:child_checkboxes()
  local contents = self.listitem:field('contents')
  for _, content in ipairs(contents) do
    if content:type() == 'list' then
      return vim.tbl_map(function(node)
        local text = ts.get_node_text(node, 0)
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

  local text = ts.get_node_text(cookie_node, 0)
  if text:match('%[%d*/%d*%]') or text:match('%[%d?%d?%d?%%%]') then
    return cookie_node
  end
end

function Listitem:update_cookie(total_child_checkboxes, checked_child_checkboxes)
  local cookie = self:cookie()
  if cookie then
    local new_cookie_val
    if ts.get_node_text(cookie, 0):find('%%') then
      new_cookie_val = ('[%d%%]'):format((#checked_child_checkboxes / #total_child_checkboxes) * 100)
    else
      new_cookie_val = ('[%d/%d]'):format(#checked_child_checkboxes, #total_child_checkboxes)
    end
    tree_utils.set_node_text(cookie, new_cookie_val)
  end
end

return Listitem

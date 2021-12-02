local utils = require('orgmode.utils')
local ts_utils = require('nvim-treesitter.ts_utils')
local headline_cookie_query = vim.treesitter.parse_query('org', '(headline (cookie) @cookie)')

local checkboxes = {}

local function _get_cookie_checked_and_total(parent)
  local checked, total = 0, 0
  for child in parent:iter_children() do
    if child:type() == 'listitem' then
      for listitem_child in child:iter_children() do
        if listitem_child:type() == 'checkbox' then
          local checkbox_text = vim.treesitter.get_node_text(listitem_child, 0)
          if checkbox_text:match('%[[x|X]%]') then
            checked = checked + 1
          end
          total = total + 1
        end
      end
    end
  end
  return checked, total
end

local function _update_checkbox_text(checkbox, checked_children, total_children)
  local checkbox_text
  if total_children == nil then -- if the function is called without child information, we toggle the current value
    checkbox_text = vim.treesitter.get_node_text(checkbox, 0)
    if checkbox_text:match('%[[xX]%]') then
      checkbox_text = '[ ]'
    else
      checkbox_text = '[X]'
    end
  else
    checkbox_text = '[ ]'
    if checked_children == total_children then
      checkbox_text = '[x]'
    elseif checked_children > 0 then
      checkbox_text = '[-]'
    end
  end

  utils.update_node_text(checkbox, { checkbox_text })
end

local function _update_cookie_text(cookie, checked_children, total_children)
  local cookie_text = vim.treesitter.get_node_text(cookie, 0)

  if total_children == nil then
    checked_children, total_children = 0, 0
  end

  local new_cookie
  if cookie_text:find('/') then
    new_cookie = string.format('[%d/%d]', checked_children, total_children)
  else
    if total_children > 0 then
      new_cookie = string.format('[%d%%%%]', (100 * checked_children) / total_children)
    else
      new_cookie = '[0%%%]'
    end
  end
  cookie_text = cookie_text:gsub('%[.*%]', new_cookie)
  utils.update_node_text(cookie, { cookie_text })
end

function checkboxes.update_checkbox(node, checked_children, total_children)
  if not node then
    node = utils.get_closest_parent_of_type(ts_utils.get_node_at_cursor(0), 'listitem')
    if not node then
      return
    end
  end

  local checkbox
  local cookie
  for child in node:iter_children() do
    if child:type() == 'checkbox' then
      checkbox = child
    elseif child:type() == 'itemtext' then
      local c_child = child:named_child(0)
      if c_child and c_child:type() == 'cookie' then
        cookie = c_child
      end
    end
  end

  if checkbox then
    _update_checkbox_text(checkbox, checked_children, total_children)
  end

  if cookie then
    _update_cookie_text(cookie, checked_children, total_children)
  end

  local listitem_parent = utils.get_closest_parent_of_type(node:parent(), 'listitem')
  if listitem_parent then
    local list_parent = utils.get_closest_parent_of_type(node, 'list')
    local checked, total = _get_cookie_checked_and_total(list_parent)
    return checkboxes.update_checkbox(listitem_parent, checked, total)
  end

  local section = utils.get_closest_parent_of_type(node:parent(), 'section')
  if section then
    local list_parent = utils.get_closest_parent_of_type(node, 'list')
    local checked, total = _get_cookie_checked_and_total(list_parent)
    local start_row, _, end_row, _ = section:range()
    for _, headline_cookie in headline_cookie_query:iter_captures(section, 0, start_row, end_row + 1) do
      _update_cookie_text(headline_cookie, checked, total)
    end
  end
end

return checkboxes

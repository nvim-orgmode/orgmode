local ts_utils = require('orgmode.utils.treesitter')
local utils = require('orgmode.utils')

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

---Cookies in the item's own paragraphs, not in its sub-lists, blocks or drawers
---@return OrgStatisticsCookie[]
function Listitem:cookies()
  local cookies = {}
  for _, content in ipairs(self.listitem:field('contents')) do
    if content:type() == 'paragraph' then
      vim.list_extend(cookies, utils.find_statistics_cookies(self.file:get_node_text(content), content))
    end
  end
  return cookies
end

function Listitem:update_cookie(total_child_checkboxes, checked_child_checkboxes)
  local cookies = self:cookies()
  local bufnr = self.file:get_valid_bufnr()
  -- Backwards, so that a replaced cookie does not move the ones before it
  for i = #cookies, 1, -1 do
    local cookie = cookies[i]
    local new_cookie_val
    if cookie.text:find('%%') then
      new_cookie_val = ('[%d%%]'):format((#checked_child_checkboxes / #total_child_checkboxes) * 100)
    else
      new_cookie_val = ('[%d/%d]'):format(#checked_child_checkboxes, #total_child_checkboxes)
    end
    local start_row, start_col, end_row, end_col = unpack(cookie.range)
    pcall(vim.api.nvim_buf_set_text, bufnr, start_row, start_col, end_row, end_col, { new_cookie_val })
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

---@param lines string[]
---@param width number
---@return string[]
local function shift_lines(lines, width)
  return vim.tbl_map(function(line)
    if width > 0 and line:match('%S') then
      return (' '):rep(width) .. line
    end
    if width < 0 then
      return (line:gsub('^' .. (' ?'):rep(-width), '', 1))
    end
    return line
  end, lines)
end

---@param value string
---@return number | nil
local function bullet_to_number(value)
  if value:match('^%a$') then
    return value:lower():byte() - ('a'):byte() + 1
  end
  return tonumber(value)
end

---Renumber an ordered list like Emacs does: numbering starts at 1, a [@N] counter sets the number of its item,
---all items take the delimiter of the first item, and the lines below a bullet that changed width are shifted with it.
---@param items string[][] lines of each item, the first line holds the bullet
local function renumber(items)
  local first_bullet, delimiter = items[1][1]:match('^%s*(%w+)([.)])')
  if not first_bullet then
    return
  end
  local letter_base = first_bullet:match('^%u$') and 'A' or first_bullet:match('^%l$') and 'a'
  local number = 0
  for i, lines in ipairs(items) do
    local indent, bullet, rest = lines[1]:match('^(%s*)(%w+)[.)](.*)$')
    if bullet then
      local counter = rest:match('^%s+%[@(%w+)%]')
      number = counter and bullet_to_number(counter) or number + 1
      local new_bullet = tostring(number)
      if letter_base then
        new_bullet = number <= 26 and string.char(letter_base:byte() + number - 1) or bullet
      end
      items[i] = shift_lines(lines, #new_bullet - #bullet)
      items[i][1] = indent .. new_bullet .. delimiter .. rest
    end
  end
end

---Swap the list item, together with its children, with the previous or next item in the same list.
---An ordered list is renumbered afterwards.
---@param direction 'up' | 'down'
---@return number | nil offset Number of lines the item moved by, nil if there is no item to swap with
function Listitem:move(direction)
  local nodes = vim.tbl_filter(function(node)
    return node:type() == 'listitem'
  end, ts_utils.get_named_children(self.listitem:parent()))
  local index
  for i, node in ipairs(nodes) do
    if node:id() == self.listitem:id() then
      index = i
    end
  end
  local other = direction == 'up' and index - 1 or index + 1
  if not nodes[other] then
    return nil
  end

  local items, gaps, starts = {}, {}, {}
  local list_start = Listitem:new(nodes[1], self.file):_line_range()
  local list_end
  for i, node in ipairs(nodes) do
    local start_row, end_row = Listitem:new(node, self.file):_line_range()
    starts[i] = start_row
    items[i] = vim.api.nvim_buf_get_lines(0, start_row, end_row, false)
    if nodes[i + 1] then
      gaps[i] = vim.api.nvim_buf_get_lines(0, end_row, (nodes[i + 1]:range()), false)
    end
    list_end = end_row
  end

  items[index], items[other] = items[other], items[index]
  renumber(items)

  local lines = {}
  local new_start
  for i, item_lines in ipairs(items) do
    if i == other then
      new_start = list_start + #lines
    end
    vim.list_extend(lines, item_lines)
    vim.list_extend(lines, gaps[i] or {})
  end
  vim.api.nvim_buf_set_lines(0, list_start, list_end, false, lines)

  return new_start - starts[index]
end

return Listitem

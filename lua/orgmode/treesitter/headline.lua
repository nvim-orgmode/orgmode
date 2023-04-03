local utils = require('orgmode.utils')
local ts_utils = require('nvim-treesitter.ts_utils')
local tree_utils = require('orgmode.utils.treesitter')
local Date = require('orgmode.objects.date')
local Range = require('orgmode.parser.range')
local config = require('orgmode.config')
local ts = require('orgmode.treesitter.compat')

---@class Headline
---@field headline userdata
local Headline = {}

---@param headline_node userdata tree sitter headline node
function Headline:new(headline_node)
  local data = { headline = headline_node }
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param cursor? Table Cursor position tuple {row, col}
---@return Headline|nil
function Headline.from_cursor(cursor)
  local ts_headline = tree_utils.closest_headline(cursor)
  if not ts_headline then
    return nil
  end
  return Headline:new(ts_headline)
end

---@return userdata stars node
function Headline:stars()
  return self.headline:field('stars')[1]
end

function Headline:refresh()
  tree_utils.parse()
  local start_row, start_col = self.headline:start()
  local updated_headline = Headline.from_cursor({ start_row + 1, start_col })
  if updated_headline then
    self.headline = updated_headline.headline
  end
  return self
end

---@return number
function Headline:level()
  local stars = self:stars()
  return ts.get_node_text(stars, 0):len()
end

function Headline:priority()
  return self:parse('%[#(%w+)%]')
end

---@param amount number
---@param recursive? boolean
function Headline:promote(amount, recursive)
  amount = math.min(amount or 1, self:level() - 1)
  recursive = recursive or false
  if self:level() == 1 then
    return utils.echo_warning('Cannot demote top level heading.')
  end

  return self:_handle_promote_demote(recursive, function(lines)
    for i, line in ipairs(lines) do
      if line:sub(1, 1) == '*' then
        lines[i] = line:sub(1 + amount)
      elseif vim.trim(line:sub(1, amount)) == '' then
        lines[i] = line:sub(1 + amount)
      end
    end
    return lines
  end)
end

---@param amount number
---@param recursive? boolean
function Headline:demote(amount, recursive)
  amount = amount or 1
  recursive = recursive or false

  return self:_handle_promote_demote(recursive, function(lines)
    for i, line in ipairs(lines) do
      if line:sub(1, 1) == '*' then
        lines[i] = string.rep('*', amount) .. line
      else
        lines[i] = config:apply_indent(line, amount)
      end
    end
    return lines
  end)
end

function Headline:_handle_promote_demote(recursive, modifier)
  local whole_subtree = function()
    local text = ts.get_node_text(self.headline:parent(), 0)
    local lines = modifier(vim.split(text, '\n', true))
    tree_utils.set_node_lines(self.headline:parent(), lines)
    return self:refresh()
  end

  if recursive then
    return whole_subtree()
  end

  local first_child_section = nil
  for _, node in ipairs(ts_utils.get_named_children(self.headline:parent())) do
    if node:type() == 'section' then
      first_child_section = node
      break
    end
  end

  if not first_child_section then
    return whole_subtree()
  end

  local start = self.headline:start()
  local end_line = first_child_section:start()
  local lines = modifier(vim.api.nvim_buf_get_lines(0, start, end_line, false))
  vim.api.nvim_buf_set_lines(0, start, end_line, false, lines)
  return self:refresh()
end

---@return userdata, string
function Headline:tags()
  local node = self.headline:field('tags')[1]
  local text = ''
  if node then
    text = ts.get_node_text(node, 0)
  end
  return node, text
end

---@param tags string
function Headline:set_tags(tags)
  local predecessor = nil
  for _, node in ipairs(ts_utils.get_named_children(self.headline)) do
    if node:type() ~= 'tag_list' then
      predecessor = node
    end
  end

  local txt = ts.get_node_text(predecessor, 0)
  local pred_end_row, pred_end_col, _ = predecessor:end_()
  local line = vim.fn.getline(pred_end_row + 1)
  local stars = line:match('^%*+%s*')
  local end_col = line:len()

  local text = ''
  tags = vim.trim(tags):gsub('^:', ''):gsub(':$', '')
  if tags ~= '' then
    tags = ':' .. tags .. ':'

    local to_col = config.org_tags_column
    local tags_width = vim.api.nvim_strwidth(tags)
    if to_col < 0 then
      to_col = math.abs(to_col) - tags_width
    end

    local spaces = math.max(to_col - (vim.api.nvim_strwidth(txt) + stars:len()), 1)
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

---@param priority string
function Headline:set_priority(priority)
  local current_priority = self:priority()
  if current_priority then
    local text = (vim.trim(priority) == '') and '' or ('[#%s]'):format(priority)
    tree_utils.set_node_text(current_priority, text)
    return
  end

  -- TODO: input validation is split between here and priority_state.lua:prompt_user().
  --       should be unified
  if vim.trim(priority) == '' then
    return
  end

  local todo = self:todo()
  if todo then
    local text = ts.get_node_text(todo, 0)
    tree_utils.set_node_text(todo, ('%s [#%s]'):format(text, priority))
    return
  end

  local stars = self:stars()
  local text = ts.get_node_text(stars, 0)
  tree_utils.set_node_text(stars, ('%s [#%s]'):format(text, priority))
end

---@param keyword string
function Headline:set_todo(keyword)
  local current_todo = self:todo()
  if current_todo then
    tree_utils.set_node_text(current_todo, keyword)
    return
  end

  local stars = self:stars()
  local text = ts.get_node_text(stars, 0)
  tree_utils.set_node_text(stars, string.format('%s %s', text, keyword))
end

function Headline:item()
  return self.headline:field('item')[1]
end

-- Returns the headlines todo node, it's keyword,
-- and if it's in done state
-- @return Node, string, boolean
function Headline:todo()
  local todo_keywords = config:get_todo_keywords()
  local keywords = todo_keywords.ALL
  local done_keywords = todo_keywords.DONE

  -- A valid keyword can only be the first child
  local todo_node = self:item():named_child(0)
  if not todo_node then
    return nil
  end

  local text = ts.get_node_text(todo_node, 0)
  for _, word in ipairs(keywords) do
    -- there may be multiple substitutions necessary
    local escaped_word = vim.pesc(word)
    local todo = text:match(escaped_word)
    if todo then
      return todo_node, word, vim.tbl_contains(done_keywords, word)
    end
  end
end

function Headline:todo_keyword()
  local node, word = self:todo()
  if not node then
    return {
      value = '',
      type = '',
      node = nil,
    }
  end

  local todo_keywords = config:get_todo_keywords()
  return {
    value = word,
    type = todo_keywords.KEYS[word].type,
    node = node,
  }
end

---@return boolean
function Headline:is_todo()
  local _, _, is_done = self:todo()
  return not is_done
end

---@return boolean
function Headline:is_done()
  return not self:is_todo()
end

function Headline:title()
  local title = ts.get_node_text(self:item(), 0) or ''
  local todo, word = self:todo()
  if todo then
    title = title:gsub('^' .. vim.pesc(word) .. '%s*', '')
  end
  return title
end

---@return userdata|nil
function Headline:plan()
  local section = self.headline:parent()
  for _, node in ipairs(ts_utils.get_named_children(section)) do
    if node:type() == 'plan' then
      return node
    end
  end
end

---@return userdata|nil
function Headline:properties()
  local section = self.headline:parent()
  for _, node in ipairs(ts_utils.get_named_children(section)) do
    if node:type() == 'property_drawer' then
      return node
    end
  end
end

---@param name string
---@param value string
function Headline:set_property(name, value)
  local properties = self:properties()
  if not properties then
    local append_line = self:get_append_line()
    local property_drawer = self:_apply_indent({ ':PROPERTIES:', ':END:' })
    vim.api.nvim_buf_set_lines(0, append_line, append_line, false, property_drawer)
    tree_utils.parse()
    properties = self:refresh():properties()
  end

  local property = (':%s: %s'):format(name, value)
  local existing_property = self:get_property(name)
  if existing_property then
    tree_utils.set_node_text(existing_property.node, property)
    return self:refresh()
  end
  local property_end = properties and properties:end_()
  vim.api.nvim_buf_set_lines(0, property_end - 1, property_end - 1, false, { self:_apply_indent(property) })
  return self:refresh()
end

---@param property_name string
---@return table|nil
function Headline:get_property(property_name)
  local properties = self:properties()
  if not properties then
    return nil
  end

  for _, node in ipairs(ts_utils.get_named_children(properties)) do
    local name = node:field('name')[1]
    local value = node:field('value')[1]
    if name and ts.get_node_text(name, 0):lower() == property_name:lower() then
      return {
        node = node,
        name = name,
        value = value and ts.get_node_text(value, 0),
      }
    end
  end
end

---Return the line number where content can be appended
---
---@return number
function Headline:get_append_line()
  local properties = self:properties()
  if properties then
    return properties:end_()
  end
  local plan = self:plan()
  if plan then
    return plan:end_()
  end
  return self.headline:end_()
end

---@return Table<string, userdata>
function Headline:dates()
  local plan = self:plan()
  local dates = {}

  if not plan then
    return dates
  end

  for _, node in ipairs(ts_utils.get_named_children(plan)) do
    local name = ts.get_node_text(node:named_child(0), 0)
    dates[name] = node
  end
  return dates
end

---@return userdata[]
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

---@return Date|nil
function Headline:deadline()
  return self:_get_date('DEADLINE')
end

---@return Date|nil
function Headline:scheduled()
  return self:_get_date('SCHEDULED')
end

---@param date Date
function Headline:set_deadline_date(date)
  return self:_add_date('DEADLINE', date, true)
end

---@param date Date
function Headline:set_scheduled_date(date)
  return self:_add_date('SCHEDULED', date, true)
end

---@param date? Date
function Headline:set_closed_date(date)
  local dates = self:dates()
  if dates['CLOSED'] then
    return
  end
  return self:_add_date('CLOSED', date or Date.now(), false)
end

function Headline:remove_closed_date()
  return self:_remove_date('CLOSED')
end

function Headline:remove_deadline_date()
  return self:_remove_date('DEADLINE')
end

function Headline:remove_scheduled_date()
  return self:_remove_date('SCHEDULED')
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
    if ts.get_node_text(cookie, 0):find('%%') then
      new_cookie_val = ('[%d%%]'):format((#checked_boxes / #total_boxes) * 100)
    else
      new_cookie_val = ('[%d/%d]'):format(#checked_boxes, #total_boxes)
    end
    tree_utils.set_node_text(cookie, new_cookie_val)
  end
end

function Headline:child_checkboxes(list_node)
  return vim.tbl_map(function(node)
    local text = ts.get_node_text(node, 0)
    return text:match('%[.%]')
  end, ts_utils.get_named_children(list_node))
end

-- @return tsnode, string
function Headline:parse(pattern)
  local match = ''
  local matching_nodes = vim.tbl_filter(function(node)
    local text = ts.get_node_text(node, 0) or ''
    local m = text:match(pattern)
    if m then
      match = text:match(pattern)
      return true
    end
  end, ts_utils.get_named_children(self:item()))
  return matching_nodes[1], match
end

---@param type string | "DEADLINE" | "SCHEDULED" | "CLOSED"
---@return Date|nil
function Headline:_get_date(type)
  local dates = self:dates()
  local date_node = dates[type]
  if not date_node then
    return nil
  end
  local timestamp_node = date_node:field('timestamp')[1]
  if not timestamp_node then
    return nil
  end
  local parsed_date = Date.from_org_date(ts.get_node_text(timestamp_node, 0), {
    range = Range.from_node(timestamp_node),
  })
  return parsed_date and parsed_date[1] or nil
end

---@param type string | "DEADLINE" | "SCHEDULED" | "CLOSED"
---@param date Date
---@param active? boolean
---@private
function Headline:_add_date(type, date, active)
  local dates = self:dates()
  local text = type .. ': ' .. date:to_wrapped_string(active)
  if vim.tbl_isempty(dates) then
    local indent = config:get_indent(self:level() + 1)
    local start_line = self.headline:start()
    vim.fn.append(start_line + 1, ('%s%s'):format(indent, text))
    return self:refresh()
  end
  if dates[type] then
    tree_utils.set_node_text(dates[type], text, true)
    return self:refresh()
  end

  local keys = vim.tbl_keys(dates)
  local other_types = vim.tbl_filter(function(t)
    return t ~= type
  end, { 'DEADLINE', 'SCHEDULED', 'CLOSED' })
  local last_child = dates[keys[#keys]]
  for _, date_type in ipairs(other_types) do
    if dates[date_type] then
      last_child = dates[date_type]
      break
    end
  end
  local ptext = ts.get_node_text(last_child, 0)
  tree_utils.set_node_text(last_child, ptext .. ' ' .. text)
  return self:refresh()
end

---@param type string | "DEADLINE" | "SCHEDULED" | "CLOSED"
---@private
function Headline:_remove_date(type)
  local dates = self:dates()
  if vim.tbl_count(dates) == 0 or not dates[type] then
    return
  end
  local line_nr = dates[type]:start() + 1
  tree_utils.set_node_text(dates[type], '', true)
  if vim.trim(vim.fn.getline(line_nr)) == '' then
    vim.fn.deletebufline(vim.api.nvim_get_current_buf(), line_nr)
  end
  return self:refresh()
end

---@param text table|string
function Headline:_apply_indent(text)
  return config:apply_indent(text, self:level() + 1)
end

return Headline

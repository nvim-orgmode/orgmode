local utils = require('orgmode.utils')
local ts_utils = require('orgmode.utils.treesitter')
local Date = require('orgmode.objects.date')
local Range = require('orgmode.files.elements.range')
local config = require('orgmode.config')
local PriorityState = require('orgmode.objects.priority_state')
local indent = require('orgmode.org.indent')
local Logbook = require('orgmode.files.elements.logbook')
local OrgId = require('orgmode.org.id')

---@alias OrgPlanDateTypes 'DEADLINE' | 'SCHEDULED' | 'CLOSED'

---@class OrgHeadline
---@field headline TSNode
---@field file OrgFile
local Headline = {}

local memoize = utils.memoize(Headline, function(self)
  ---@cast self OrgHeadline
  return table.concat({
    self.file.filename,
    self.headline:id(),
    self.file.metadata.mtime,
  }, '_')
end)

---@param headline_node TSNode tree sitter headline node
---@param file OrgFile
function Headline:new(headline_node, file)
  local data = {
    headline = headline_node,
    file = file,
  }
  setmetatable(data, self)
  return data
end

---Return up to date headline node
---@return TSNode
function Headline:node()
  local bufnr = self.file:bufnr()
  if bufnr < 0 then
    return self.headline
  end
  return self:refresh().headline
end

--- Refresh the headline
--- @return OrgHeadline
function Headline:refresh()
  local start_row, start_col = self.headline:start()
  local updated_headline = self.file:closest_headline_node({ start_row + 1, start_col })
  if updated_headline then
    self.headline = updated_headline
  end
  return self
end

memoize('get_level')
---@return number
function Headline:get_level()
  local _, end_col = self:_get_child_node('stars'):end_()
  return end_col
end

memoize('get_priority')
---@return string, TSNode | nil
function Headline:get_priority()
  local _, todo_node = self:get_todo()
  local item = self:_get_child_node('item')

  local priority_node = item and item:named_child(1)

  if not todo_node then
    priority_node = item and item:named_child(0)
  end

  if priority_node then
    local text = self.file:get_node_text(priority_node)
    local priority = text:match('%[#(%w+)%]')
    if priority then
      local priorities = config:get_priorities()
      if priorities[priority] then
        return priority, priority_node
      end
    end
  end
  return '', nil
end

---@param amount number
---@param recursive? boolean
---@param dryRun? boolean
---@return string[]
function Headline:promote(amount, recursive, dryRun)
  amount = math.min(amount or 1, self:get_level() - 1)
  recursive = recursive or false
  if self:get_level() == 1 then
    utils.echo_warning('Cannot demote top level heading.')
    return {}
  end

  return self:_handle_promote_demote(recursive, function(start_line, lines)
    for i, line in ipairs(lines) do
      if line:sub(1, 1) == '*' then
        lines[i] = line:sub(1 + amount)
      elseif vim.trim(line:sub(1, amount)) == '' then
        if config:should_indent(self.file:bufnr()) then
          lines[i] = line:sub(1 + amount)
        else
          line, _ = line:gsub('^%s+', '')
          local indent_amount = indent.indentexpr(start_line + i, self.file:bufnr())
          lines[i] = string.rep(' ', indent_amount) .. line
        end
      end
    end
    return lines
  end, dryRun)
end

---@param amount number
---@param recursive? boolean
---@param dryRun? boolean
---@return string[]
function Headline:demote(amount, recursive, dryRun)
  amount = amount or 1
  recursive = recursive or false

  return self:_handle_promote_demote(recursive, function(start_line, lines)
    for i, line in ipairs(lines) do
      if line:sub(1, 1) == '*' then
        lines[i] = string.rep('*', amount) .. line
      else
        if config:should_indent(self.file:bufnr()) then
          lines[i] = self:_apply_indent(line, amount)
        else
          line, _ = line:gsub('^%s+', '')
          local indent_amount = indent.indentexpr(start_line + i, self.file:bufnr())
          lines[i] = string.rep(' ', indent_amount) .. line
        end
      end
    end
    return lines
  end, dryRun)
end

---@return boolean
function Headline:is_clocked_in()
  local logbook = self:get_logbook()
  return logbook and logbook:is_active() or false
end

function Headline:clock_in()
  local logbook = self:get_logbook()
  if not logbook then
    logbook = Logbook.new_from_headline(self)
  end
  logbook:add_clock_in()
  return self:refresh()
end

function Headline:clock_out()
  local logbook = self:get_logbook()
  if logbook then
    logbook:clock_out()
  end
  return self:refresh()
end

function Headline:cancel_active_clock()
  local logbook = self:get_logbook()
  if logbook then
    logbook:cancel_active_clock()
  end
  return self:refresh()
end

---@return OrgLogbook | nil
function Headline:get_logbook()
  local drawer = self:get_drawer('logbook')
  if drawer then
    return Logbook.from_node(drawer, self.file, self:get_non_plan_dates())
  end
  return nil
end

---@return OrgDate | nil
function Headline:get_closed_date()
  return utils.find(self:get_all_dates(), function(date)
    return date:is_closed()
  end)
end

function Headline:get_priority_sort_value()
  local priority = self:get_priority()
  return PriorityState:new(priority):get_sort_value()
end

function Headline:is_archived()
  return #vim.tbl_filter(function(tag)
    return tag:upper() == 'ARCHIVE'
  end, self:get_tags()) > 0
end

---Check if headline has tag
---@param tag string
---@return boolean
function Headline:has_tag(tag)
  for _, tag_item in ipairs(self:get_tags()) do
    if tag_item:lower() == tag:lower() then
      return true
    end
  end
  return false
end

memoize('get_category')
--- @return string
function Headline:get_category()
  local category = self:get_property('category', true)

  if category then
    return category
  end

  return self.file:get_category()
end

---@param tags string
function Headline:set_tags(tags)
  ---@type TSNode
  local predecessor = nil
  for _, node in ipairs(ts_utils.get_named_children(self:node())) do
    if node:type() ~= 'tag_list' then
      predecessor = node
    end
  end

  if not predecessor then
    return nil
  end

  local txt = self.file:get_node_text(predecessor)
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
  local current_text, tags_node = self:tags_to_string()
  if tags_node then
    self:set_tags(current_text)
  end
end

---@param priority string
function Headline:set_priority(priority)
  local _, priority_node = self:get_priority()
  if priority_node then
    local text = (vim.trim(priority) == '') and '' or ('[#%s]'):format(priority)
    return self:_set_node_text(priority_node, text)
  end

  local todo, todo_node = self:get_todo()
  if todo then
    return self:_set_node_text(todo_node, ('%s [#%s]'):format(todo, priority))
  end

  local stars = self:_get_child_node('stars')
  local _, level = stars:end_()
  return self:_set_node_text(stars, ('%s [#%s]'):format(('*'):rep(level), priority))
end

---@param keyword string
function Headline:set_todo(keyword)
  local todo, node = self:get_todo()
  if todo then
    return self:_set_node_text(node, keyword)
  end

  local stars = self:_get_child_node('stars')
  local _, level = stars:end_()
  return self:_set_node_text(stars, ('%s %s'):format(('*'):rep(level), keyword))
end

memoize('get_todo')
--- Returns the headlines todo keyword, it's node,
--- and it's type (todo or done)
--- @return string | nil, TSNode | nil, string | nil
function Headline:get_todo()
  -- A valid keyword can only be the first child
  local first_item_node = self:_get_child_node('item')
  local todo_node = first_item_node and first_item_node:named_child(0)
  if not todo_node then
    return nil, nil, nil
  end

  local todo_keywords = config:get_todo_keywords()

  local text = self.file:get_node_text(todo_node)
  local keyword_by_value = todo_keywords:find(text)
  if not keyword_by_value then
    return nil, nil, nil
  end

  return text, todo_node, keyword_by_value.type
end

---@return boolean
function Headline:is_todo()
  local _, _, type = self:get_todo()
  return type == 'TODO'
end

---@return boolean
function Headline:is_done()
  local _, _, type = self:get_todo()
  return type == 'DONE'
end

memoize('get_title')
---@return string
function Headline:get_title()
  local title = self.file:get_node_text(self:_get_child_node('item')) or ''
  local word, todo_node = self:get_todo()
  if todo_node and word then
    title = title:gsub('^' .. vim.pesc(word) .. '%s*', '')
  end
  local priority, priority_node = self:get_priority()
  if priority_node then
    title = title:gsub('^' .. vim.pesc(('[#%s]'):format(priority)) .. '%s*', '')
  end
  return title
end

function Headline:get_title_with_priority()
  local priority = self:get_priority()
  local title = self:get_title()
  if priority ~= '' then
    return ('[#%s] %s'):format(priority, self:get_title())
  end
  return title
end

---@return TSNode | nil, table<string, string>
function Headline:get_properties()
  local section = self:node():parent()
  local properties_node = section and section:field('property_drawer')[1]

  if not properties_node then
    return nil, {}
  end

  local properties = {}

  if properties_node then
    for _, node in ipairs(ts_utils.get_named_children(properties_node)) do
      local name = node:field('name')[1]
      local value = node:field('value')[1]

      if name and value then
        properties[self.file:get_node_text(name):lower()] = self.file:get_node_text(value)
      end
    end
  end

  return properties_node, properties
end

---@param name string
---@param value string
function Headline:set_property(name, value)
  local properties = self:get_properties()
  if not properties then
    local append_line = self:get_append_line()
    local property_drawer = self:_apply_indent({ ':PROPERTIES:', ':END:' }) --[[ @as string[] ]]
    vim.api.nvim_buf_set_lines(0, append_line, append_line, false, property_drawer)
    properties = self:refresh():get_properties()
  end

  local property = (':%s: %s'):format(name, value)
  local existing_property, property_node = self:get_property(name)
  if existing_property then
    return self:_set_node_text(property_node, property)
  end
  local property_end = properties and properties:end_()

  local new_line = self:_apply_indent(property) --[[@as string]]
  vim.api.nvim_buf_set_lines(0, property_end - 1, property_end - 1, false, { new_line })
  return self:refresh()
end

---@param property_name string
---@param search_parents? boolean
---@return string | nil, TSNode | nil
function Headline:get_property(property_name, search_parents)
  local properties = self:get_properties()
  if properties then
    for _, node in ipairs(ts_utils.get_named_children(properties)) do
      local name = node:field('name')[1]
      local value = node:field('value')[1]
      if name and self.file:get_node_text(name):lower() == property_name:lower() then
        return value and self.file:get_node_text(value), node
      end
    end
  end

  if not search_parents then
    return nil, nil
  end

  local parent_section = self:node():parent():parent()
  while parent_section do
    local headline_node = parent_section:field('headline')[1]
    if headline_node then
      local headline = Headline:new(headline_node, self.file)
      local property, property_node = headline:get_property(property_name)
      if property then
        return property, property_node
      end
    end
    parent_section = parent_section:parent()
  end

  return nil, nil
end

function Headline:matches_search_term(term)
  if self:get_title():lower():match(term) then
    return true
  end
  local body = self.file:get_node_text(self:node():parent():field('body')[1])
  return body:lower():match(term) ~= nil
end

function Headline:content()
  return self.file:get_node_text_list(self:node():parent():field('body')[1])
end

---@return OrgDate[]
function Headline:get_deadline_and_scheduled_dates()
  local dates = { self:get_deadline_date(), self:get_scheduled_date() }
  return vim.tbl_filter(function(date)
    return date ~= nil
  end, dates)
end

---@return OrgDate | nil
function Headline:get_scheduled_date()
  local dates = self:get_plan_dates()
  return vim.tbl_get(dates, 'SCHEDULED', 1)
end

---@return OrgDate | nil
function Headline:get_deadline_date()
  local dates = self:get_plan_dates()
  return vim.tbl_get(dates, 'DEADLINE', 1)
end

memoize('get_tags')
---@return string[], TSNode | nil
function Headline:get_tags()
  local tags, own_tags_node = self:get_own_tags()
  if not config.org_use_tag_inheritance then
    return config:exclude_tags(tags), own_tags_node
  end

  local parent_tags = {}
  local parent_section = self:node():parent():parent()
  while parent_section do
    local headline = parent_section:field('headline')[1]
    if headline then
      local node = headline:field('tags')[1]
      if node then
        local parent_tags_list = utils.parse_tags_string(self.file:get_node_text(node))
        utils.concat(parent_tags, utils.reverse(parent_tags_list), true)
      end
    end
    parent_section = parent_section:parent()
  end
  local file_tags = self.file:get_filetags()

  local all_tags = utils.concat({}, file_tags)
  utils.concat(all_tags, utils.reverse(parent_tags), true)
  utils.concat(all_tags, tags, true)

  return config:exclude_tags(all_tags), own_tags_node
end

---@return OrgHeadline | nil
function Headline:get_parent_headline()
  local parent_section = self:node():parent():parent()
  if not parent_section then
    return nil
  end

  local headline = parent_section:field('headline')[1]
  return Headline:new(headline, self.file)
end

memoize('get_own_tags')
---@return string[], TSNode | nil
function Headline:get_own_tags()
  local node = self:_get_child_node('tags')
  if node then
    return utils.parse_tags_string(self.file:get_node_text(node)), node
  end
  return {}, nil
end

---@return OrgDate[]
function Headline:get_repeater_dates()
  return vim.tbl_filter(function(date)
    return date:get_repeater()
  end, self:get_all_dates())
end

---@return boolean
function Headline:is_first_section()
  return self:get_prev_headline_same_level() == nil
end

---@return boolean
function Headline:is_last_section()
  return self:get_next_headline_same_level() == nil
end

---@return OrgHeadline | nil
function Headline:get_prev_headline_same_level()
  local prev_section = self:node():parent():prev_named_sibling()
  if not prev_section or prev_section:type() ~= 'section' then
    return nil
  end

  return Headline:new(prev_section:field('headline')[1], self.file)
end

---@return OrgHeadline | nil
function Headline:get_next_headline_same_level()
  local next_section = self:node():parent():next_named_sibling()
  if not next_section or next_section:type() ~= 'section' then
    return nil
  end

  return Headline:new(next_section:field('headline')[1], self.file)
end

---@return number
function Headline:get_append_line()
  local properties = self:get_properties()
  if properties then
    local row = properties:end_()
    return row
  end
  local plan = self:node():parent():field('plan')[1]
  if plan then
    local _, _, has_plan_dates = self:get_plan_dates()
    if has_plan_dates then
      local row = plan:end_()
      return row
    end
  end
  local row = self:node():end_()
  return row
end

memoize('get_plan_dates')
---@return OrgTable<OrgPlanDateTypes, OrgDate[]>,OrgTable<OrgPlanDateTypes, TSNode>, boolean
function Headline:get_plan_dates()
  local plan = self:node():parent():field('plan')[1]
  local dates = {}
  local dates_nodes = {}
  local has_plan_dates = false

  if not plan then
    return dates, dates_nodes, has_plan_dates
  end

  local valid_plan_types = { 'SCHEDULED', 'DEADLINE', 'CLOSED', 'NONE' }

  for _, node in ipairs(ts_utils.get_named_children(plan)) do
    local name_node = node:field('name')[1]
    local name = name_node and self.file:get_node_text(name_node) or 'NONE'
    local timestamp = node:field('timestamp')[1]

    if vim.tbl_contains(valid_plan_types, name:upper()) then
      if name_node then
        has_plan_dates = true
      end
      dates[name:upper()] = Date.from_org_date(self.file:get_node_text(timestamp), {
        range = Range.from_node(timestamp),
        type = name:upper(),
      })
      dates_nodes[name:upper()] = node
    end
  end
  return dates, dates_nodes, has_plan_dates
end

memoize('get_all_dates')
---Return all dates including the ones added to the body of the headline
---@return OrgDate[]
function Headline:get_all_dates()
  local d = self:get_plan_dates()
  local plan_dates = utils.flatten(vim.tbl_values(d))
  local body_dates_list = self:get_non_plan_dates()

  return vim.list_extend(plan_dates, body_dates_list)
end

memoize('get_non_plan_dates')
---@return OrgDate[]
function Headline:get_non_plan_dates()
  local section = self:node():parent()
  local body = section and section:field('body')[1]
  local headline_text = self.file:get_node_text(self:_get_child_node('item')) or ''
  local dates = Date.parse_all_from_line(headline_text, self:node():start() + 1)
  local properties_node = section and section:field('property_drawer')[1]

  if properties_node then
    local properties_text = self.file:get_node_text_list(properties_node) or {}
    local start = properties_node:start()
    for i, line in ipairs(properties_text) do
      vim.list_extend(dates, Date.parse_all_from_line(line, start + i))
    end
  end

  if not body then
    return dates
  end

  local start_line = body:range()
  local lines = self.file:get_node_text_list(body)
  for i, line in ipairs(lines) do
    local line_dates = Date.parse_all_from_line(line, start_line + i)
    local is_clock_line = line:match('^%s*:?CLOCK:') ~= nil
    for _, date in ipairs(line_dates) do
      -- Assume that the date is part of logbook if line starts with clock
      -- TODO: Make this more reliable
      if not date.active and is_clock_line then
        date.type = 'LOGBOOK'
      end
    end
    vim.list_extend(dates, line_dates)
  end

  return dates
end

function Headline:tags_to_string()
  local tags, node = self:get_tags()
  return utils.tags_to_string(tags), node
end

---@return boolean
function Headline:has_child_headlines()
  return self:node():parent():field('subsection')[1] ~= nil
end

---@return boolean
function Headline:is_one_line()
  local start_row, _, end_row, end_col = self:node():parent():range()
  -- One line sections have end range on the next line with 0 column
  -- Example: If headline is on line 5, range will be (5, 1, 6, 0)
  return start_row == end_row or (start_row + 1 == end_row and end_col == 0)
end

memoize('get_child_headlines')
---@return OrgHeadline[]
function Headline:get_child_headlines()
  local child_sections = self:node():parent():field('subsection')
  local headlines = vim.tbl_map(function(child_section)
    return Headline:new(child_section:field('headline')[1], self.file)
  end, child_sections)

  return headlines
end

---@param category string
---@return boolean
function Headline:matches_category(category)
  return self:get_category():lower() == category:lower()
end

---@return OrgDate[]
function Headline:get_valid_dates_for_agenda()
  local dates = {}
  for _, date in ipairs(self:get_all_dates()) do
    if date.active and not date:is_closed() and not date:is_obsolete_range_end() then
      table.insert(dates, date)
      if not date:is_none() and date.related_date_range then
        local new_date = date:clone({ type = 'NONE' })
        table.insert(dates, new_date)
      end
    end
  end
  return dates
end

---@param date OrgDate
function Headline:set_deadline_date(date)
  return self:_add_date('DEADLINE', date, true)
end

---@param date OrgDate
function Headline:set_scheduled_date(date)
  return self:_add_date('SCHEDULED', date, true)
end

---@param date? OrgDate
function Headline:set_closed_date(date)
  local dates = self:get_plan_dates()
  if vim.tbl_get(dates, 'CLOSED', 1) then
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

function Headline:get_cookie()
  local cookie = self:_parse_title_part('%[%d*/%d*%]')
  if cookie then
    return cookie
  end
  return self:_parse_title_part('%[%d?%d?%d?%%%]')
end

function Headline:update_cookie(list_node)
  local total_boxes = self:child_checkboxes(list_node)
  local checked_boxes = vim.tbl_filter(function(box)
    return box:match('%[%w%]')
  end, total_boxes)

  local cookie = self:get_cookie()
  if cookie then
    local new_cookie_val
    if self.file:get_node_text(cookie):find('%%') then
      new_cookie_val = ('[%d%%]'):format((#checked_boxes / #total_boxes) * 100)
    else
      new_cookie_val = ('[%d/%d]'):format(#checked_boxes, #total_boxes)
    end
    return self:_set_node_text(cookie, new_cookie_val)
  end
end

function Headline:child_checkboxes(list_node)
  return vim.tbl_map(function(node)
    local text = self.file:get_node_text(node)
    return text:match('%[.%]')
  end, ts_utils.get_named_children(list_node))
end

---@return TSNode | nil
function Headline:get_drawer(name)
  local section = self:node():parent()
  if not section then
    return nil
  end
  local body = section:field('body')[1]
  if not body then
    return nil
  end

  for _, node in ipairs(ts_utils.get_named_children(body)) do
    if node:type() == 'drawer' then
      local drawer_name = node:field('name')
      if #drawer_name and string.lower(self.file:get_node_text(drawer_name[1])) == string.lower(name) then
        return node
      end
    end
  end
end

---Return the line number where content can be appended within
---the drawer with the given name, matched case-insensitively
---@param name string
---@return number
function Headline:get_drawer_append_line(name)
  local drawer = self:get_drawer(name)

  if not drawer then
    local append_line = self:get_append_line()
    local new_drawer = self:_apply_indent({ ':' .. name .. ':', ':END:' }) --[[ @as string[] ]]
    vim.api.nvim_buf_set_lines(0, append_line, append_line, false, new_drawer)
    drawer = self:get_drawer(name)
  end
  local name_row = drawer and drawer:field('name')[1]:end_() or 0
  return name_row + 1
end

---@return OrgRange
function Headline:get_range()
  return Range.from_node(self:node():parent())
end

---@return string[]
function Headline:get_lines()
  return self.file:get_node_text_list(self:node():parent())
end

---@return string
function Headline:get_headline_line_content()
  local line = self.file:get_node_text(self:node()):gsub('\n', '')
  return line
end

---@param amount? number
---@return string
function Headline:get_indent(amount)
  return config:get_indent(amount or self:get_level() + 1, self.file:bufnr())
end

function Headline:is_same(other_headline)
  return self.file.filename == other_headline.filename
    and self:get_range():is_same(other_headline:get_range())
    and self:get_headline_line_content() == other_headline:get_headline_line_content()
end

function Headline:id_get_or_create()
  local id_prop = self:get_property('ID')
  if id_prop then
    return vim.trim(id_prop)
  end
  local org_id = OrgId.new()
  self:set_property('ID', org_id)
  return org_id
end

---@param type OrgPlanDateTypes
---@param date OrgDate
---@param active? boolean
---@private
function Headline:_add_date(type, date, active)
  local _, date_nodes, has_plan_dates = self:get_plan_dates()
  local text = type .. ': ' .. date:to_wrapped_string(active)
  if not has_plan_dates then
    local start_line = self:node():start()
    vim.fn.append(start_line + 1, self:_apply_indent(text))
    return self:refresh()
  end
  if date_nodes[type] then
    return self:_set_node_text(date_nodes[type], text)
  end

  local keys = vim.tbl_keys(date_nodes)
  local other_types = vim.tbl_filter(function(t)
    return t ~= type
  end, { 'DEADLINE', 'SCHEDULED', 'CLOSED' })
  local last_child = date_nodes[keys[#keys]]
  for _, date_type in ipairs(other_types) do
    if date_nodes[date_type] then
      last_child = date_nodes[date_type]
      break
    end
  end
  local ptext = self.file:get_node_text(last_child)
  return self:_set_node_text(last_child, ptext .. ' ' .. text)
end

---@param type OrgPlanDateTypes
---@private
function Headline:_remove_date(type)
  local _, date_nodes = self:get_plan_dates()
  if vim.tbl_count(date_nodes) == 0 or not date_nodes[type] then
    return
  end
  local line_nr = date_nodes[type]:start() + 1
  self.file:set_node_text(date_nodes[type], '', true)
  if vim.trim(vim.fn.getline(line_nr)) == '' then
    vim.fn.deletebufline(vim.api.nvim_get_current_buf(), line_nr)
  end
  return self:refresh()
end

---@param text string[]|string
---@param amount? number
function Headline:_apply_indent(text, amount)
  local indent_text = self:get_indent(amount)

  if indent_text == '' then
    return text
  end

  if type(text) ~= 'table' then
    return indent_text .. text
  end

  for i, line in ipairs(text) do
    text[i] = indent_text .. line
  end

  return text
end

function Headline:_get_child_node(name)
  return self:node():field(name)[1]
end

---@param node? TSNode
---@param text string
---@return OrgHeadline
function Headline:_set_node_text(node, text)
  self.file:set_node_text(node, text)
  return self:refresh()
end

---@param node? TSNode
---@param text string[]
---@return OrgHeadline
function Headline:_set_node_lines(node, text)
  self.file:set_node_lines(node, text)
  return self:refresh()
end

---@private
---@return TSNode | nil, string
function Headline:_parse_title_part(pattern)
  for _, node in ipairs(ts_utils.get_named_children(self:_get_child_node('item'))) do
    local text = self.file:get_node_text(node) or ''
    local match = text:match(pattern)
    if match then
      return node, match
    end
  end

  return nil, ''
end

---@private
---@param recursive? boolean
---@param modifier function
---@param dryRun? boolean
function Headline:_handle_promote_demote(recursive, modifier, dryRun)
  local whole_subtree = function()
    local parent = self:node():parent()
    local text = self.file:get_node_text(parent)
    local start = parent and parent:start()
    local lines = modifier(start, vim.split(text, '\n', { plain = true }))
    if dryRun then
      return lines
    end
    return self:_set_node_lines(self:node():parent(), lines)
  end

  if recursive then
    return whole_subtree()
  end

  local first_child_section = nil
  for _, node in ipairs(ts_utils.get_named_children(self:node():parent())) do
    if node:type() == 'section' then
      first_child_section = node
      break
    end
  end

  if not first_child_section then
    return whole_subtree()
  end

  local start = self:node():start()
  local end_line = first_child_section:start()
  local lines = modifier(start, vim.api.nvim_buf_get_lines(0, start, end_line, false))
  if dryRun then
    return lines
  end
  vim.api.nvim_buf_set_lines(0, start, end_line, false, lines)
  return self:refresh()
end

return Headline

-- TODO
-- Add parsing dates from headline
-- Add markup to headline
-- Handle hide leading stars with treesitter highlight
local ts_utils = require('nvim-treesitter.ts_utils')
local Range = require('orgmode.parser.range')
local utils = require('orgmode.utils')
local PriorityState = require('orgmode.objects.priority_state')
local Date = require('orgmode.objects.date')
local Logbook = require('orgmode.parser.logbook')
local config = require('orgmode.config')

---@class Section
---@field id string
---@field line_number number
---@field level number
---@field node TSNode
---@field root File
---@field parent Section
---@field line string
---@field range Range
---@field sections Section[]
---@field todo_keyword SectionTodoKeyword
---@field priority string
---@field title string
---@field category string
---@field file string
---@field content string[]
---@field dates Date[]
---@field properties SectionProperties
---@field tags string[]
---@field own_tags string[]
---@field logbook Logbook
---@field clocked_in boolean
local Section = {}

---@class SectionProperties
---@field items table<string, string>
---@field range Range
---@field node TSNode
---@field valid boolean

---@class SectionTodoKeyword
---@field node unknown
---@field type 'TODO'|'DONE'|''
---@field value string

---@class NewSectionOptions
---@field content string[]
---@field dates Date[]
---@field level number
---@field line string
---@field logbook Logbook
---@field node TSNode
---@field own_tags string[]
---@field parent Section
---@field priority string
---@field properties table
---@field range Range
---@field root File
---@field tags string[]
---@field title string
---@field todo_keyword_node unknown

---Constructs a new Section
---@param data NewSectionOptions
---@return Section
function Section:new(data)
  data = data or {}

  ---@type Section
  local section = {}
  section.id = string.format('%s####%s', data.root.filename or '', data.range.start_line)
  section.line_number = data.range.start_line
  section.level = data.level or 0
  section.root = data.root
  section.parent = data.parent
  section.line = data.line
  section.range = data.range
  section.sections = {}
  section.todo_keyword = { value = '', type = '', node = data.todo_keyword_node }
  section.priority = data.priority
  section.title = data.title
  section.category = data.properties.items.category or (data.parent and data.parent.category) or data.root.category
  section.file = data.root.filename or ''
  section.dates = data.dates or {}
  section.properties = data.properties
  section.own_tags = { unpack(data.own_tags or {}) }
  section.tags = utils.concat(config:get_inheritable_tags(data.parent or {}), data.tags, true)
  section.content = data.content or {}
  section.logbook = data.logbook
  section.clocked_in = data.logbook and data.logbook:is_active()
  section.node = data.node
  setmetatable(section, self)
  self.__index = self
  section:_parse()
  return section
end

---@param section_node table
---@param file File
---@return Section
function Section.from_node(section_node, file, parent)
  local data = {
    level = 0,
    title = '',
    line = '',
    tags = not parent and config:get_inheritable_tags(file) or {},
    own_tags = {},
    dates = {},
    range = Range.from_node(section_node),
    parent = parent,
    root = file,
    content = {},
    properties = { items = {} },
    node = section_node,
    todo_keyword_node = nil,
    logbook = nil,
  }
  local child_sections = {}

  for child in section_node:iter_children() do
    if child:type() == 'plan' then
      for entry in child:iter_children() do
        if entry:type() == 'entry' then
          local first_node = entry:named_child(0)
          local first_node_text = file:get_node_text(first_node)
          if entry:named_child_count() == 1 and first_node:type() == 'timestamp' then
            utils.concat(
              data.dates,
              Date.from_org_date(first_node_text, {
                range = Range.from_node(first_node),
              })
            )
          end
          if entry:named_child_count() == 2 and first_node:type() == 'entry_name' then
            local valid_plan_types = { 'SCHEDULED', 'DEADLINE', 'CLOSED' }
            local type = 'NONE'
            if vim.tbl_contains(valid_plan_types, first_node_text:upper()) then
              type = first_node_text
            end
            local timestamp = file:get_node_text(entry:named_child(1))
            utils.concat(
              data.dates,
              Date.from_org_date(timestamp, {
                range = Range.from_node(entry:named_child(1)),
                type = type,
              })
            )
          end
        end
      end
    end
    if child:type() == 'body' then
      local start_line = child:range()
      local lines = file:get_node_text_list(child)
      for i, line in ipairs(lines) do
        utils.concat(data.dates, Date.parse_all_from_line(line, start_line + i))
      end
      local drawers = file:get_ts_matches('(drawer) @drawer', child)
      for _, drawer_item in ipairs(drawers) do
        local drawer = drawer_item.drawer
        if drawer and drawer.text:upper() == ':LOGBOOK:' then
          if data.logbook then
            data.logbook:add(drawer.text_list, drawer.node, data.dates)
          else
            data.logbook = Logbook.parse(drawer.text_list, drawer.node, data.dates)
          end
        end
      end
    end

    if child:type() == 'property_drawer' then
      data.properties.range = Range.from_node(child)
      data.properties.node = child
      data.properties.valid = true
      for prop in child:iter_children() do
        local line = file:get_node_text(prop)
        local prop_name, prop_value = line:match('^%s*:([^:]-):%s*(.*)$')
        if prop_name and prop_value and vim.trim(prop_value) ~= '' then
          data.properties.items[prop_name:lower()] = prop_value
        end
      end
    end

    if child:type() == 'headline' then
      data.line = file:get_node_text(child)
      utils.concat(data.dates, Date.parse_all_from_line(data.line, data.range.start_line))
      data.level = file:get_node_text(child:child(0)):len()
      for headline_node in child:iter_children() do
        if headline_node:type() == 'item' then
          data.title = file:get_node_text(headline_node)
          data.todo_keyword_node = headline_node:child(0)
        end
        if headline_node:type() == 'tag_list' then
          local tags = ts_utils.get_named_children(headline_node)
          for _, tag_node in ipairs(tags) do
            local tag = file:get_node_text(tag_node)
            if not vim.tbl_contains(data.tags, tag) then
              table.insert(data.tags, tag)
            end
            if not vim.tbl_contains(data.own_tags, tag) then
              table.insert(data.own_tags, tag)
            end
          end
        end
      end
    end

    if child:type() == 'body' then
      data.content = file:get_node_text_list(child)
    end

    if child:type() == 'section' then
      table.insert(child_sections, child)
    end
  end

  local section = Section:new(data)

  for _, child_section_node in ipairs(child_sections) do
    local child_section = Section.from_node(child_section_node, file, section)
    section:add_section(child_section)
  end

  return section
end

---@param section Section
function Section:add_section(section)
  table.insert(self.sections, section)
end

---@return boolean
function Section:has_priority()
  return vim.trim(self.priority or '') ~= ''
end

---@return number
function Section:get_priority_sort_value()
  return PriorityState:new(self.priority):get_sort_value()
end

---@return Date[]
function Section:get_valid_dates_for_agenda()
  local dates = {}
  for _, date in ipairs(self.dates) do
    if date.active and not date:is_closed() and not date:is_obsolete_range_end() then
      table.insert(dates, date)
      if not date:is_none() and date.is_date_range_start then
        local new_date = date:clone({ type = 'NONE' })
        table.insert(dates, new_date)
      end
    end
  end
  return dates
end

function Section:is_archived()
  return #vim.tbl_filter(function(tag)
    return tag:upper() == 'ARCHIVE'
  end, self.tags) > 0
end

---@return boolean
function Section:is_todo()
  return self.todo_keyword.type == 'TODO'
end

---@return boolean
function Section:is_done()
  return self.todo_keyword.type == 'DONE'
end

---@return string
function Section:tags_to_string()
  return utils.tags_to_string(self.tags)
end

function Section:get_category()
  return self.category
end

---@param tag string
---@return boolean
function Section:has_tag(tag)
  for _, tag_item in ipairs(self.tags) do
    if tag_item:lower() == tag:lower() then
      return true
    end
  end
  return false
end

---@return boolean
function Section:has_children()
  return #self.sections > 0 or not self.range:is_same_line()
end

---@param category string
---@return boolean
function Section:matches_category(category)
  return self:get_category():lower() == category:lower()
end

---@param name string
---@return string|nil
function Section:get_property(name)
  return self.properties.items[name:lower()]
end

---@return table<string, string>
function Section:get_properties()
  return self.properties and self.properties.items or {}
end

function Section:matches_search_term(term)
  if self.title:lower():match(term) then
    return true
  end
  for _, content in ipairs(self.content) do
    if content:lower():match(term) then
      return true
    end
  end
  return false
end

---@return Date[]
function Section:get_deadline_and_scheduled_dates()
  return vim.tbl_filter(function(date)
    return date:is_deadline() or date:is_scheduled()
  end, self.dates)
end

---@return Date
function Section:get_scheduled_date()
  return vim.tbl_filter(function(date)
    return date:is_scheduled()
  end, self.dates)[1]
end

---@return Date
function Section:get_deadline_date()
  return vim.tbl_filter(function(date)
    return date:is_deadline()
  end, self.dates)[1]
end

---@return string[]
function Section:get_own_tags()
  return { unpack(self.own_tags) }
end

---@return Date[]
function Section:get_repeater_dates()
  return vim.tbl_filter(function(date)
    return date:get_repeater()
  end, self.dates)
end

---@return boolean
function Section:is_first_section()
  if not self.parent then
    return self.root.sections[1].id == self.id
  end
  return self.parent.sections[1].id == self.id
end

---@return boolean
function Section:is_last_section()
  if not self.parent then
    return self.root.sections[#self.root.sections].id == self.id
  end
  return self.parent.sections[#self.parent.sections].id == self.id
end

---@return Section?
function Section:get_prev_headline_same_level()
  if self:is_first_section() then
    return nil
  end
  local parent = self.parent or self.root
  local len = #parent.sections
  for i = 1, len do
    local section = parent.sections[len + 1 - i]
    if section.line_number < self.line_number and section.level == self.level then
      return section
    end
  end
  return nil
end

---@return Section?
function Section:get_next_headline_same_level()
  if self:is_last_section() then
    return nil
  end
  local parent = self.parent or self.root
  for _, section in ipairs(parent.sections) do
    if section.line_number > self.line_number and section.level == self.level then
      return section
    end
  end
  return nil
end

---@param amount number
---@param demote_child_sections? boolean
---@param dryRun? boolean
function Section:demote(amount, demote_child_sections, dryRun)
  amount = amount or 1
  demote_child_sections = demote_child_sections or false
  local should_indent = config.org_indent_mode == 'indent'
  local lines = {}
  local headline_line = string.rep('*', amount) .. self.line
  table.insert(lines, headline_line)
  if not dryRun then
    vim.api.nvim_call_function('setline', { self.range.start_line, headline_line })
  end
  local contents = self.root:get_node_text_list(self.node)
  for i, content in ipairs(contents) do
    if i > 1 then
      if content:match('^%*+') then
        break
      end
      local content_line = content
      if should_indent then
        content_line = string.rep(' ', amount) .. content
      end
      table.insert(lines, content_line)
      if not dryRun and should_indent then
        vim.api.nvim_call_function('setline', { self.range.start_line + i - 1, content_line })
      end
    end
  end
  if demote_child_sections then
    for _, section in ipairs(self.sections) do
      utils.concat(lines, section:demote(amount, true, dryRun))
    end
  end
  return lines
end

---@param amount number
---@param promote_child_sections? boolean
---@param dryRun? boolean
---@return string[]
function Section:promote(amount, promote_child_sections, dryRun)
  amount = amount or 1
  promote_child_sections = promote_child_sections or false
  local should_dedent = config.org_indent_mode == 'indent'
  local lines = {}
  if self.level == 1 then
    utils.echo_warning('Cannot demote top level heading.')
    return lines
  end
  local headline_line = self.line:sub(1 + amount)
  table.insert(lines, headline_line)
  if not dryRun then
    vim.api.nvim_call_function('setline', { self.range.start_line, headline_line })
  end
  if should_dedent then
    local contents = self.root:get_node_text_list(self.node)
    for i, content in ipairs(contents) do
      if i > 1 then
        if content:match('^%*+') then
          break
        end
        local can_dedent = vim.trim(content:sub(1, amount)) == ''
        local content_line = content
        if can_dedent then
          content_line = content:sub(1 + amount)
        end
        table.insert(lines, content_line)
        if not dryRun and can_dedent then
          vim.api.nvim_call_function('setline', { self.range.start_line + i - 1, content_line })
        end
      end
    end
  end

  if promote_child_sections then
    for _, section in ipairs(self.sections) do
      utils.concat(lines, section:promote(amount, true, dryRun))
    end
  end

  return lines
end

---@return boolean
function Section:has_planning()
  for _, date in ipairs(self.dates) do
    if date:is_planning_date() then
      return true
    end
  end
  return false
end

function Section:is_clocked_in()
  return self.clocked_in
end

function Section:clock_in()
  if self.logbook then
    self.logbook:add_clock_in()
    self.clocked_in = self.logbook:is_active()
    return
  end

  self.logbook = Logbook.new_from_section(self)
  self.clocked_in = self.logbook:is_active()
end

function Section:clock_out()
  if not self.logbook then
    return
  end
  self.logbook:clock_out()
  self.clocked_in = self.logbook:is_active()
end

function Section:cancel_active_clock()
  if not self.logbook then
    return
  end
  self.logbook:cancel_active_clock()
  self.clocked_in = self.logbook:is_active()
end

---@return Date
function Section:get_closed_date()
  return vim.tbl_filter(function(date)
    return date:is_closed()
  end, self.dates)[1]
end

---@private
function Section:_parse()
  self.priority = self.line:match(self.todo_keyword.value .. '%s+%[#([A-Z0-9])%]') or ''
  self:_parse_todo_keyword()
end

---@private
function Section:_parse_todo_keyword()
  if not self.todo_keyword.node then
    return
  end

  local keyword = self.root:get_node_text(self.todo_keyword.node)
  local todo_keywords = config:get_todo_keywords()

  if keyword == '' or not todo_keywords.KEYS[keyword] then
    self.todo_keyword.node = nil
    return
  end

  local keyword_info = todo_keywords.KEYS[keyword]
  self.title = self.title:gsub('^' .. vim.pesc(keyword) .. '%s*', '')
  self.todo_keyword = {
    value = keyword,
    type = keyword_info.type,
    range = Range.from_node(self.todo_keyword.node),
  }
end

function Section:get_title()
  if not self:has_priority() then
    return self.title
  end
  local title = self.title:gsub('^%[#([A-Z0-9])%]%s*', '')
  return title
end

return Section

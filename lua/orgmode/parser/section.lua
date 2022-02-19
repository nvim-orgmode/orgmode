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
---@field id number
---@field line_number number
---@field level number
---@field node table
---@field root File
---@field parent Section
---@field line string
---@field range Range
---@field sections Section[]
---@field todo_keyword table<string, string>
---@field priority string
---@field title string
---@field category string
---@field file string
---@field content string[]
---@field dates Date[]
---@field properties table
---@field tags string[]
---@field own_tags string[]
---@field logbook Logbook
---@field clocked_in boolean
local Section = {}

function Section:new(data)
  data = data or {}
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
  section.category = data.properties.items.category or data.root.category
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

---@param priority string
function Section:set_priority(priority)
  if not priority then
    return
  end

  local linenr = self.range.start_line
  local stars = string.rep('%*', self.level)
  local static_state = self.todo_keyword.value

  local changing_state = ''
  if self.priority ~= '' then
    changing_state = '%[#' .. self.priority .. '%]%s+'
  end

  local new_state = ''
  if vim.trim(priority) ~= '' then
    new_state = '%[#' .. priority .. '%] '
  end

  local existing_line = vim.api.nvim_call_function('getline', { linenr })
  local new_line = existing_line:gsub(
    '^' .. stars .. '%s+' .. static_state .. (static_state ~= '' and '%s+' or '') .. changing_state,
    stars .. (static_state ~= '' and ' ' or '') .. static_state .. ' ' .. new_state
  )

  if existing_line == new_line then
    return
  end

  vim.api.nvim_call_function('setline', {
    linenr,
    new_line,
  })

  self.priority = vim.trim(priority)
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

---@param properties table
---@return table
function Section:add_properties(properties)
  if self.properties.valid then
    local start = vim.api.nvim_call_function('getline', { self.properties.range.start_line })
    local indent = start:match('^%s*')
    for name, val in pairs(properties) do
      if self.properties.items[name:lower()] then
        local properties_content = self.root:get_node_text_list(self.properties.node)
        for i, content in ipairs(properties_content) do
          if content:lower():match('^%s*:' .. name:lower() .. ':.*$') then
            local new_line = content:gsub(vim.pesc(self.properties.items[name:lower()]), val)
            vim.api.nvim_call_function('setline', { self.properties.range.start_line + i - 1, new_line })
            break
          end
        end
      else
        vim.api.nvim_call_function('append', {
          self.properties.range.start_line,
          string.format('%s:%s: %s', indent, name, val),
        })
      end
    end
    return {
      is_new = false,
      indent = indent,
    }
  end

  local properties_line = self:has_planning() and self.range.start_line + 1 or self.range.start_line
  local indent = ''
  if config.org_indent_mode == 'indent' then
    indent = string.rep(' ', self.level + 1)
  end
  local content = { string.format('%s:PROPERTIES:', indent) }

  for name, val in pairs(properties) do
    table.insert(content, string.format('%s:%s: %s', indent, name, val))
  end

  table.insert(content, string.format('%s:END:', indent))
  vim.api.nvim_call_function('append', { properties_line, content })
  return {
    is_new = true,
    end_line = properties_line + #content,
    indent = indent,
  }
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

---@return Section
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

---@return Section
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
---@param demote_child_sections boolean
function Section:demote(amount, demote_child_sections)
  amount = amount or 1
  demote_child_sections = demote_child_sections or false
  vim.api.nvim_call_function('setline', { self.range.start_line, string.rep('*', amount) .. self.line })
  if config.org_indent_mode == 'indent' then
    local contents = self.root:get_node_text_list(self.node)
    for i, content in ipairs(contents) do
      if i > 1 then
        if content:match('^%*+') then
          break
        end
        vim.api.nvim_call_function('setline', { self.range.start_line + i - 1, string.rep(' ', amount) .. content })
      end
    end
  end
  if demote_child_sections then
    for _, section in ipairs(self.sections) do
      section:demote(amount, true)
    end
  end
end

---@param amount number
---@param promote_child_sections boolean
function Section:promote(amount, promote_child_sections)
  amount = amount or 1
  promote_child_sections = promote_child_sections or false
  if self.level == 1 then
    return utils.echo_warning('Cannot demote top level heading.')
  end
  vim.api.nvim_call_function('setline', { self.range.start_line, self.line:sub(1 + amount) })
  if config.org_indent_mode == 'indent' then
    local contents = self.root:get_node_text_list(self.node)
    for i, content in ipairs(contents) do
      if i > 1 then
        if content:match('^%*+') then
          break
        end
        if vim.trim(content:sub(1, amount)) == '' then
          vim.api.nvim_call_function('setline', { self.range.start_line + i - 1, content:sub(1 + amount) })
        end
      end
    end
  end
  if promote_child_sections then
    for _, section in ipairs(self.sections) do
      section:promote(amount, true)
    end
  end
end

function Section:add_closed_date()
  local closed_date = self:_get_closed_date()
  if closed_date then
    return nil
  end
  return self:_add_planning_date(Date.now(), 'CLOSED')
end

---@param date Date
function Section:add_scheduled_date(date)
  local scheduled_date = self:get_scheduled_date()
  if scheduled_date then
    return self:_update_date(scheduled_date, date)
  end
  return self:_add_planning_date(date, 'SCHEDULED', true)
end

---@param date Date
function Section:add_deadline_date(date)
  local deadline_date = self:get_deadline_date()
  if deadline_date then
    return self:_update_date(deadline_date, date)
  end
  return self:_add_planning_date(date, 'DEADLINE', true)
end

function Section:remove_closed_date()
  local closed_date = self:_get_closed_date()
  if not closed_date then
    return nil
  end
  local planning_linenr = self.range.start_line + 1
  local planning_line = vim.api.nvim_call_function('getline', { planning_linenr })
  local new_line = planning_line:gsub('%s*CLOSED:%s*[%[<]' .. vim.pesc(closed_date:to_string()) .. '[%]>]', '')
  if vim.trim(new_line) == '' then
    return vim.api.nvim_call_function('deletebufline', { vim.api.nvim_get_current_buf(), planning_linenr })
  end
  return vim.api.nvim_call_function('setline', { planning_linenr, new_line })
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
function Section:_get_closed_date()
  return vim.tbl_filter(function(date)
    return date:is_closed()
  end, self.dates)[1]
end

---@private
function Section:_parse()
  self:_parse_todo_keyword()
  self.priority = self.line:match(self.todo_keyword.value .. '%s+%[#([A-Z0-9])%]') or ''
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
  self.title = self.title:gsub('^' .. keyword .. '%s*', '')
  self.todo_keyword = {
    value = keyword,
    type = keyword_info.type,
    range = Range.from_node(self.todo_keyword.node),
  }
end

function Section:_update_date(date, new_date)
  date = date:set({
    year = new_date.year,
    month = new_date.month,
    day = new_date.day,
  })
  local line = vim.api.nvim_call_function('getline', { date.range.start_line })
  local view = vim.fn.winsaveview()
  local new_line = string.format(
    '%s%s%s',
    line:sub(1, date.range.start_col),
    date:to_string(),
    line:sub(date.range.end_col)
  )
  vim.api.nvim_call_function('setline', {
    date.range.start_line,
    new_line,
  })
  vim.fn.winrestview(view)
  return true
end

---@param date Date
---@param type string
---@param active boolean
---@return string
function Section:_add_planning_date(date, type, active)
  local date_string = date:to_wrapped_string(active)
  if self:has_planning() then
    local planning_linenr = self.range.start_line + 1
    return vim.api.nvim_call_function('setline', {
      planning_linenr,
      string.format('%s %s: %s', vim.api.nvim_call_function('getline', { planning_linenr }), type, date_string),
    })
  end

  local indent = ''
  if config.org_indent_mode == 'indent' then
    indent = string.rep(' ', self.level + 1)
  end
  return vim.api.nvim_call_function('append', {
    self.range.start_line,
    string.format('%s%s: %s', indent, type, date_string),
  })
end

return Section

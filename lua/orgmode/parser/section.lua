-- TODO
-- Add parsing dates from headline
-- Add markup to headline
-- Handle hide leading stars with treesitter highlight
local ts_utils = require('nvim-treesitter.ts_utils')
local Range = require('orgmode.parser.range')
local utils = require('orgmode.utils')
local Date = require('orgmode.objects.date')
local config = require('orgmode.config')

---@class Section
---@field id number
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
local Section = {}

function Section:new(data)
  data = data or {}
  local section = {}
  section.id = data.range.start_line
  section.level = data.level or 0
  section.root = data.root
  section.parent = data.parent
  section.line = data.line
  section.range = data.range
  section.sections = {}
  section.todo_keyword = { value = '', type = '', node = data.todo_keyword_node }
  section.priority = data.priority
  section.title = data.title
  section.category = data.properties.items.CATEGORY or data.root.category
  section.file = data.root.filename or ''
  section.dates = data.dates or {}
  section.properties = data.properties
  section.own_tags = { unpack(data.own_tags or {}) }
  section.tags = utils.concat(config:get_inheritable_tags(data.parent or {}), data.tags, true)
  section.content = data.content or {}
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
  }
  local child_sections = {}

  for child in section_node:iter_children() do
    if child:type() == 'plan' then
      for _, plan_date in ipairs(ts_utils.get_named_children(child)) do
        local date = file:get_node_text(plan_date:child(0))
        utils.concat(
          data.dates,
          Date.from_org_date(date, {
            type = plan_date:type():upper(),
            range = Range.from_node(plan_date:child(0)),
          })
        )
      end
    end
    if child:type() == 'body' then
      local dates = file:get_ts_matches('(timestamp) @timestamp', child)
      for _, date in ipairs(dates) do
        utils.concat(
          data.dates,
          Date.from_org_date(date.timestamp.text, {
            range = Range.from_node(date.timestamp.node),
          })
        )
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
          data.properties.items[prop_name] = prop_value
        end
      end
    end

    if child:type() == 'headline' then
      data.line = file:get_node_text(child)
      data.level = file:get_node_text(child:child(0)):len()
      local item = child:child(1)
      if item then
        data.title = file:get_node_text(item)
        data.todo_keyword_node = item:child(0)
      end
      local tags = file:get_ts_matches('(tag) @tag', child)
      for _, match in ipairs(tags) do
        if not vim.tbl_contains(data.tags, match.tag.text) then
          table.insert(data.tags, match.tag.text)
        end
        if not vim.tbl_contains(data.own_tags, match.tag.text) then
          table.insert(data.own_tags, match.tag.text)
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
  return self.priority ~= ''
end

---@return number
function Section:get_priority_number()
  if self.priority == config.org_priority_highest then
    return 2000
  end
  if self.priority == config.org_priority_lowest then
    return 0
  end
  return 1000
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
      if self.properties.items[name] then
        local properties_content = self.root:get_node_text_list(self.properties.node)
        for i, content in ipairs(properties_content) do
          if content:match('^%s*:' .. name .. ':.*$') then
            local new_line = content:gsub(vim.pesc(self.properties.items[name]), val)
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
    if section.id < self.id and section.level == self.level then
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
    if section.id > self.id and section.level == self.level then
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
    if not date:is_none() then
      return true
    end
  end
  return false
end

---@return string
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
  local date_string = string.format('%s%s%s', active and '<' or '[', date:to_string(), active and '>' or ']')
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

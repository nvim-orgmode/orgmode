local Date = require('orgmode.objects.date')
local Files = require('orgmode.files')
local config = require('orgmode.config')
local AgendaFilter = require('orgmode.agenda.filter')
local AgendaItem = require('orgmode.agenda.agenda_item')
local AgendaView = require('orgmode.agenda.view.init')
local AgendaLine = require('orgmode.agenda.view.line')
local AgendaLineToken = require('orgmode.agenda.view.token')
local ClockReport = require('orgmode.clock.report')
local utils = require('orgmode.utils')
local SortingStrategy = require('orgmode.agenda.sorting_strategy')
local Promise = require('orgmode.utils.promise')

---@class OrgAgendaTypeOpts
---@field files OrgFiles
---@field highlighter OrgHighlighter
---@field agenda_filter OrgAgendaFilter
---@field filter? string
---@field tag_filter? string
---@field category_filter? string
---@field agenda_files string | string[] | nil
---@field span? OrgAgendaSpan
---@field from? OrgDate
---@field start_on_weekday? number
---@field start_day? string
---@field header? string
---@field show_clock_report? boolean
---@field sorting_strategy? OrgAgendaSortingStrategy[]
---@field remove_tags? boolean
---@field id? string

---@class OrgAgendaType:OrgAgendaViewType
---@field files OrgFiles
---@field highlighter OrgHighlighter
---@field agenda_filter OrgAgendaFilter
---@field filter? OrgAgendaFilter
---@field tag_filter? OrgAgendaFilter
---@field category_filter? OrgAgendaFilter
---@field agenda_files string | string[] | nil
---@field span? OrgAgendaSpan
---@field from? OrgDate
---@field to? OrgDate
---@field bufnr? number
---@field start_on_weekday? number
---@field start_day? string
---@field header? string
---@field show_clock_report? boolean
---@field clock_report? OrgClockReport
---@field clock_report_view? OrgAgendaView
---@field sorting_strategy? OrgAgendaSortingStrategy[]
---@field remove_tags? boolean
---@field valid_filters? OrgAgendaFilter[]
---@field id? string
local OrgAgendaType = {}
OrgAgendaType.__index = OrgAgendaType

---@param opts OrgAgendaTypeOpts
function OrgAgendaType:new(opts)
  local data = {
    files = opts.files,
    highlighter = opts.highlighter,
    agenda_filter = opts.agenda_filter,
    filter = opts.filter and AgendaFilter:new():parse(opts.filter, true) or nil,
    tag_filter = opts.tag_filter and AgendaFilter:new({ types = { 'tags' } }):parse(opts.tag_filter, true) or nil,
    category_filter = opts.category_filter and AgendaFilter:new({ types = { 'categories' } })
      :parse(opts.category_filter, true) or nil,
    span = opts.span or config:get_agenda_span(),
    from = opts.from or Date.today(),
    to = nil,
    clock_report = nil,
    show_clock_report = opts.show_clock_report or false,
    start_on_weekday = utils.if_nil(opts.start_on_weekday, config.org_agenda_start_on_weekday),
    start_day = utils.if_nil(opts.start_day, config.org_agenda_start_day),
    agenda_files = opts.agenda_files,
    header = opts.header,
    sorting_strategy = opts.sorting_strategy or vim.tbl_get(config.org_agenda_sorting_strategy, 'agenda') or {},
    id = opts.id,
    remove_tags = utils.if_nil(opts.remove_tags, config.org_agenda_remove_tags),
  }
  data.valid_filters = vim.tbl_filter(function(filter)
    return filter and true or false
  end, {
    data.filter,
    data.tag_filter,
    data.category_filter,
    data.agenda_filter,
  })
  local this = setmetatable(data, OrgAgendaType)
  this:_set_date_range()
  this:_setup_agenda_files()
  return this
end

function OrgAgendaType:prepare()
  return Promise.resolve(self)
end

function OrgAgendaType:redo()
  if self.agenda_files then
    self.files:load_sync(true)
  end
end

function OrgAgendaType:_setup_agenda_files()
  if not self.agenda_files then
    return
  end
  self.files = Files:new({
    paths = self.agenda_files,
    cache = true,
  }):load_sync(true)
end

function OrgAgendaType:advance_span(count, direction)
  count = count or 1
  direction = direction * count
  local action = { [self.span] = direction }
  if type(self.span) == 'number' then
    action = { day = self.span * direction }
  end
  self.from = self.from:add(action)
  self.to = self.to:add(action)
  return self
end

function OrgAgendaType:change_span(span)
  if span == self.span then
    return
  end
  if span == 'year' then
    local c = vim.fn.confirm('Are you sure you want to print agenda for the whole year?', '&Yes\n&No')
    if c ~= 1 then
      return
    end
  end
  local from = nil
  if self.view and self.view:is_in_range() then
    local agenda_line = self:get_line(vim.fn.line('.'))
    local metadata = agenda_line and agenda_line.metadata or {}
    ---@type OrgDate
    local cursor_date = metadata.agenda_day or (metadata.agenda_item and metadata.agenda_item.date)
    if cursor_date and type(span) == 'string' then
      from = cursor_date:start_of(span)
    end
  end
  self.span = span
  self:_set_date_range(from)
  return self
end

function OrgAgendaType:_jump_to_date(date)
  for _, line in ipairs(self.view.lines) do
    if line.metadata.agenda_day and line.metadata.agenda_day:is_same(date, 'day') then
      return vim.fn.cursor({ line.line_nr, 0 })
    end
  end
end

function OrgAgendaType:goto_date(date)
  self.to = nil
  self:_set_date_range(date)
  local was_line_in_view = self.view:is_in_range(vim.fn.line('.'))
  self.after_render = function()
    if was_line_in_view then
      self:_jump_to_date(date)
    end
  end
end

function OrgAgendaType:reset()
  return self:goto_date(Date.today())
end

---@return OrgAgendaLine[]
function OrgAgendaType:get_lines()
  return self.view.lines
end

---@param row number
---@return OrgAgendaLine | nil
function OrgAgendaType:get_line(row)
  return utils.find(self.view.lines, function(line)
    return line.line_nr == row
  end)
end

---@private
---@param line? number
---@return OrgDate
function OrgAgendaType:_get_jump_to_date(line)
  line = line or vim.fn.line('.')
  if not self.view then
    return Date.now():start_of('day')
  end
  if self.span == 'day' then
    return self.from
  end

  local agenda_line = self:get_line(line)
  if not agenda_line then
    return self.from
  end

  ---@type OrgDate
  local agenda_line_date = agenda_line.metadata.agenda_day
    or (agenda_line.metadata.agenda_item and agenda_line.metadata.agenda_item.date)

  if not agenda_line_date then
    return self.from
  end

  if self.span == 'week' then
    local range = self.from:get_range_until(self.to)
    for _, date in ipairs(range) do
      if date:get_isoweekday() == agenda_line_date:get_isoweekday() then
        return date
      end
    end
  end

  if self.span == 'month' then
    return self.from:set({ day = agenda_line_date.day })
  end

  if self.span == 'year' then
    return self.from:set({ day = agenda_line_date.day, month = agenda_line_date.month })
  end

  return self.from
end

---@param bufnr? number
---@param current_line? number
function OrgAgendaType:render(bufnr, current_line)
  self.bufnr = bufnr or 0
  local jump_to_date = self.from
  local was_line_in_view = true
  if self.view then
    was_line_in_view = self.view:is_in_range(current_line)
  end
  if was_line_in_view then
    jump_to_date = self:_get_jump_to_date(current_line)
  end
  local agenda_days = self:_get_agenda_days()

  local agendaView = AgendaView:new({ bufnr = self.bufnr, highlighter = self.highlighter })
  agendaView:add_line(AgendaLine:single_token({
    content = self:_get_title(),
    hl_group = '@org.agenda.header',
  }))

  for _, agenda_day in ipairs(agenda_days) do
    local is_today = agenda_day.day:is_today()
    local is_weekend = agenda_day.day:is_weekend()
    local add_highlight = is_today or is_weekend

    agendaView:add_line(AgendaLine:single_token({
      content = self:_format_day(agenda_day.day),
      hl_group = add_highlight and (is_today and '@org.agenda.today' or '@org.agenda.weekend') or nil,
    }, {
      metadata = {
        agenda_day = agenda_day.day,
      },
    }))

    for _, agenda_item in ipairs(agenda_day.agenda_items) do
      agendaView:add_line(self:_build_line(agenda_item, agenda_day))
    end
  end

  if self.show_clock_report then
    agendaView:add_line(AgendaLine:single_token({
      content = '',
    }))
    local clock_report = ClockReport:new({
      from = self.from,
      to = self.to,
      files = self.files,
    }):get_table_report(agendaView.lines[#agendaView.lines].line_nr)

    for _, row in ipairs(clock_report.rows) do
      local line = AgendaLine:new({
        separator = '|',
      })
      for i, cell in ipairs(row.cells) do
        if i == 1 then
          line:add_token(AgendaLineToken:new({
            content = '',
            hl_group = '@org.bold',
          }))
        end
        local hl_group = '@org.bold'
        if cell.reference then
          line.headline = cell.reference
          hl_group = '@org.hyperlink'
        end
        line:add_token(AgendaLineToken:new({
          content = cell.content,
          hl_group = hl_group,
          trim_for_hl = true,
        }))
      end
      line:add_token(AgendaLineToken:new({
        content = '',
        hl_group = '@org.bold',
      }))
      agendaView:add_line(line)
    end
  end

  self.view = agendaView:render()
  if self.after_render then
    self.after_render()
    self.after_render = nil
  elseif was_line_in_view then
    self:_jump_to_date(jump_to_date)
  end
  return self.view
end

---@private
---@param agenda_item OrgAgendaItem
---@param metadata table<string, any>
---@return OrgAgendaLine
function OrgAgendaType:_build_line(agenda_item, metadata)
  local headline = agenda_item.headline
  local item_hl_group = agenda_item:get_hlgroup()
  local line = AgendaLine:new({
    hl_group = item_hl_group,
    line_hl_group = headline:is_clocked_in() and 'Visual' or nil,
    headline = headline,
    metadata = {
      agenda_item = agenda_item,
      category_length = metadata.category_length,
      label_length = metadata.label_length,
    },
  })
  line:add_token(AgendaLineToken:new({
    content = '  ' .. utils.pad_right(('%s:'):format(headline:get_category()), metadata.category_length),
  }))
  line:add_token(AgendaLineToken:new({
    content = utils.pad_right(agenda_item.label, metadata.label_length),
  }))
  local todo = headline:get_todo()
  if todo then
    local todo_hl_group = agenda_item:get_todo_hlgroup()
    line:add_token(AgendaLineToken:new({
      content = todo,
      hl_group = todo_hl_group,
    }))
  end
  local priority = headline:get_priority()
  if priority ~= '' then
    local priority_hl_group = agenda_item:get_priority_hlgroup()
    line:add_token(AgendaLineToken:new({
      content = ('[#%s]'):format(tostring(priority)),
      hl_group = priority_hl_group,
    }))
  end
  line:add_token(AgendaLineToken:new({
    content = headline:get_title(),
    add_markup_to_headline = headline,
  }))
  if not self.remove_tags and #headline:get_tags() > 0 then
    local tags_string = headline:tags_to_string()
    line:add_token(AgendaLineToken:new({
      content = tags_string,
      virt_text_pos = 'right_align',
      hl_group = '@org.agenda.tag',
    }))
  end

  return line
end

---@param agenda_line OrgAgendaLine
---@param headline OrgHeadline
function OrgAgendaType:rerender_agenda_line(agenda_line, headline)
  agenda_line.metadata.agenda_item:set_headline(headline)
  local line = self:_build_line(agenda_line.metadata.agenda_item, agenda_line.metadata)
  self.view:replace_line(agenda_line, line)
end

---@return { day: OrgDate, agenda_items: OrgAgendaItem[], category_length: number, label_length: 0 }[]
function OrgAgendaType:_get_agenda_days()
  local dates = self.from:get_range_until(self.to)
  local agenda_days = {}

  local headline_dates = {}
  for _, orgfile in ipairs(self.files:all()) do
    for _, headline in ipairs(orgfile:get_opened_headlines()) do
      for _, headline_date in ipairs(headline:get_valid_dates_for_agenda()) do
        table.insert(headline_dates, {
          headline_date = headline_date,
          headline = headline,
        })
      end
    end
  end

  local headlines = {}
  for _, day in ipairs(dates) do
    local date = { day = day, agenda_items = {}, category_length = 0, label_length = 0 }

    for index, item in ipairs(headline_dates) do
      local headline = item.headline
      local agenda_item = AgendaItem:new(item.headline_date, headline, day, index)
      if agenda_item.is_valid and self:_matches_filters(headline) then
        table.insert(headlines, headline)
        table.insert(date.agenda_items, agenda_item)
        date.category_length = math.max(date.category_length, vim.api.nvim_strwidth(headline:get_category()))
        date.label_length = math.max(date.label_length, vim.api.nvim_strwidth(agenda_item.label))
      end
    end

    date.agenda_items = self:_sort(date.agenda_items)
    date.category_length = math.max(11, date.category_length + 1)
    date.label_length = math.min(11, date.label_length)

    table.insert(agenda_days, date)
  end

  return agenda_days
end

function OrgAgendaType:toggle_clock_report()
  self.show_clock_report = not self.show_clock_report
  return self
end

function OrgAgendaType:_matches_filters(headline)
  for _, filter in ipairs(self.valid_filters) do
    if filter and not filter:matches(headline) then
      return false
    end
  end
  return true
end

function OrgAgendaType:_set_date_range(from)
  local span = self.span
  from = from or self.from

  if self.start_on_weekday then
    local is_week = span == 'week' or span == '7'
    if is_week and from:is_same(Date.today(), 'week') then
      from = from:set_isoweekday(self.start_on_weekday)
    end
  end
  local to = nil
  local modifier = { [span] = 1 }
  if type(span) == 'number' then
    modifier = { day = span }
  end

  to = from:add(modifier)

  if self.start_day and type(self.start_day) == 'string' then
    from = from:adjust(self.start_day)
    to = to:adjust(self.start_day)
  end

  self.span = span
  self.from = from
  self.to = to
end

---@return string
function OrgAgendaType:_get_title()
  if self.header ~= nil then
    return self.header
  end
  local span = self.span
  if type(span) == 'number' then
    span = string.format('%d days', span)
  end
  local span_number = ''
  span_number = string.format(' (W%s)', self.from:format('%V'))
  return utils.capitalize(span) .. '-agenda' .. span_number .. ':'
end

function OrgAgendaType:_format_day(day)
  return string.format('%-10s %s', day:format('%A'), day:format('%d %B %Y'))
end

---@private
---@param agenda_items OrgAgendaItem[]
---@return OrgAgendaItem[]
function OrgAgendaType:_sort(agenda_items)
  ---@param agenda_item OrgAgendaItem
  local make_entry = function(agenda_item)
    return {
      date = agenda_item.real_date,
      headline = agenda_item.headline,
      index = agenda_item.index,
      is_day_match = agenda_item.is_same_day,
    }
  end

  return SortingStrategy.sort(agenda_items, self.sorting_strategy, make_entry)
end

return OrgAgendaType

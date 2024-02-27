local Date = require('orgmode.objects.date')
local Range = require('orgmode.files.elements.range')
local config = require('orgmode.config')
local ClockReport = require('orgmode.clock.report')
local AgendaItem = require('orgmode.agenda.agenda_item')
local AgendaFilter = require('orgmode.agenda.filter')
local utils = require('orgmode.utils')

local function sort_by_date_or_priority_or_category(a, b)
  if a.headline:get_priority_sort_value() ~= b.headline:get_priority_sort_value() then
    return a.headline:get_priority_sort_value() > b.headline:get_priority_sort_value()
  end
  if not a.real_date:is_same(b.real_date, 'day') then
    return a.real_date:is_before(b.real_date)
  end
  return a.index < b.index
end

---@param agenda_items OrgAgendaItem[]
---@return OrgAgendaItem[]
local function sort_agenda_items(agenda_items)
  table.sort(agenda_items, function(a, b)
    if a.is_same_day and b.is_same_day then
      if a.real_date:has_time() and not b.real_date:has_time() then
        return true
      end
      if b.real_date:has_time() and not a.real_date:has_time() then
        return false
      end
      if a.real_date:has_time() and b.real_date:has_time() then
        return a.real_date:is_before(b.real_date)
      end
      return sort_by_date_or_priority_or_category(a, b)
    end

    if a.is_same_day and not b.is_same_day then
      if a.real_date:has_time() or (b.real_date:is_none() and not a.real_date:is_none()) then
        return true
      end
    end

    if not a.is_same_day and b.is_same_day then
      if b.real_date:has_time() or (a.real_date:is_none() and not b.real_date:is_none()) then
        return false
      end
    end

    return sort_by_date_or_priority_or_category(a, b)
  end)
  return agenda_items
end

---@class OrgAgendaView
---@field span string|number
---@field from OrgDate
---@field to OrgDate
---@field items table[]
---@field content table[]
---@field highlights table[]
---@field clock_report OrgClockReport
---@field show_clock_report boolean
---@field start_on_weekday number
---@field start_day string
---@field header string
---@field filters OrgAgendaFilter
---@field files OrgFiles
local AgendaView = {}

function AgendaView:new(opts)
  opts = opts or {}
  local data = {
    content = {},
    highlights = {},
    items = {},
    span = opts.span or config:get_agenda_span(),
    from = opts.from or Date.now():start_of('day'),
    to = nil,
    filters = opts.filters or AgendaFilter:new(),
    clock_report = nil,
    show_clock_report = opts.show_clock_report or false,
    start_on_weekday = opts.org_agenda_start_on_weekday or config.org_agenda_start_on_weekday,
    start_day = opts.org_agenda_start_day or config.org_agenda_start_day,
    header = opts.org_agenda_overriding_header,
    files = opts.files,
  }

  setmetatable(data, self)
  self.__index = self
  data:_set_date_range()
  return data
end

function AgendaView:_get_title()
  if self.header then
    return self.header
  end
  local span = self.span
  if type(span) == 'number' then
    span = string.format('%d days', span)
  end
  local span_number = ''
  if span == 'week' then
    span_number = string.format(' (W%s)', self.from:get_week_number())
  end
  return utils.capitalize(span) .. '-agenda' .. span_number .. ':'
end

function AgendaView:_set_date_range(from)
  local span = self.span
  from = from or self.from
  local is_week = span == 'week' or span == '7'
  if is_week and self.start_on_weekday then
    from = from:set_isoweekday(self.start_on_weekday)
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

function AgendaView:_build_items()
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

  for _, day in ipairs(dates) do
    local date = { day = day, agenda_items = {} }

    for index, item in ipairs(headline_dates) do
      local agenda_item = AgendaItem:new(item.headline_date, item.headline, day, index)
      if agenda_item.is_valid and self.filters:matches(item.headline) then
        table.insert(date.agenda_items, agenda_item)
      end
    end

    date.agenda_items = sort_agenda_items(date.agenda_items)

    table.insert(agenda_days, date)
  end

  self.items = agenda_days
end

function AgendaView:build()
  self:_build_items()
  local content = { { line_content = self:_get_title() } }
  local highlights = {}
  for _, item in ipairs(self.items) do
    local day = item.day
    local agenda_items = item.agenda_items

    local is_today = day:is_today()
    local is_weekend = day:is_weekend()

    if is_today or is_weekend then
      table.insert(highlights, {
        hlgroup = is_today and '@org.agenda.today' or '@org.agenda.weekend',
        range = Range:new({
          start_line = #content + 1,
          end_line = #content + 1,
          start_col = 1,
          end_col = 0,
        }),
      })
    end

    table.insert(content, { line_content = self:_format_day(day) })

    local longest_items = utils.reduce(agenda_items, function(acc, agenda_item)
      acc.category = math.max(acc.category, vim.api.nvim_strwidth(agenda_item.headline:get_category()))
      acc.label = math.max(acc.label, vim.api.nvim_strwidth(agenda_item.label))
      return acc
    end, {
      category = 0,
      label = 0,
    })
    local category_len = math.max(11, (longest_items.category + 1))
    local date_len = math.min(11, longest_items.label)

    for _, agenda_item in ipairs(agenda_items) do
      table.insert(content, AgendaView.build_agenda_item_content(agenda_item, category_len, date_len, #content))
    end
  end

  self.content = content
  self.highlights = highlights
  self.active_view = 'agenda'
  if self.show_clock_report then
    self.clock_report = ClockReport:new({
      from = self.from,
      to = self.to,
      files = self.files,
    })
    utils.concat(self.content, self.clock_report:draw_for_agenda(#self.content + 1))
  end
  return self
end

function AgendaView:advance_span(direction, count)
  count = count or 1
  direction = direction * count
  local action = { [self.span] = direction }
  if type(self.span) == 'number' then
    action = { day = self.span * direction }
  end
  self.from = self.from:add(action)
  self.to = self.to:add(action)
  return self:build()
end

function AgendaView:change_span(span)
  if span == self.span then
    return
  end
  if span == 'year' then
    local c = vim.fn.confirm('Are you sure you want to print agenda for the whole year?', '&Yes\n&No')
    if c ~= 1 then
      return
    end
  end
  self.span = span
  self:_set_date_range()
  return self:build()
end

function AgendaView:goto_date(date)
  self.to = nil
  self:_set_date_range(date)
  self:build()
  vim.schedule(function()
    vim.fn.search(self:_format_day(date))
  end)
end

function AgendaView:reset()
  return self:goto_date(Date.now():start_of('day'))
end

function AgendaView:toggle_clock_report()
  self.show_clock_report = not self.show_clock_report
  local text = self.show_clock_report and 'on' or 'off'
  utils.echo_info(string.format('Clocktable mode is %s', text))
  return self:build()
end

function AgendaView:after_print(_)
  return vim.fn.search(self:_format_day(Date.now()))
end

---@param agenda_item OrgAgendaItem
---@return table
function AgendaView.build_agenda_item_content(agenda_item, longest_category, longest_date, line_nr)
  local headline = agenda_item.headline
  local category = '  ' .. utils.pad_right(string.format('%s:', headline:get_category()), longest_category)
  local date = agenda_item.label
  if date ~= '' then
    date = ' ' .. utils.pad_right(agenda_item.label, longest_date)
  end
  local todo_keyword = agenda_item.headline:get_todo() or ''
  local todo_padding = ''
  if todo_keyword ~= '' and vim.trim(agenda_item.label):find(':$') then
    todo_padding = ' '
  end
  todo_keyword = todo_padding .. todo_keyword
  local line = string.format('%s%s%s %s', category, date, todo_keyword, headline:get_title_with_priority())
  local todo_keyword_pos = string.format('%s%s%s', category, date, todo_padding):len()
  if #headline:get_tags() > 0 then
    local tags_string = headline:tags_to_string()
    local padding_length =
      math.max(1, utils.winwidth() - vim.api.nvim_strwidth(line) - vim.api.nvim_strwidth(tags_string))
    local indent = string.rep(' ', padding_length)
    line = string.format('%s%s%s', line, indent, tags_string)
  end

  local item_highlights = {}
  if #agenda_item.highlights then
    item_highlights = vim.tbl_map(function(hl)
      hl.range = Range:new({
        start_line = line_nr + 1,
        end_line = line_nr + 1,
        start_col = 1,
        end_col = 0,
      })
      if hl.todo_keyword then
        hl.range.start_col = todo_keyword_pos + 1
        hl.range.end_col = todo_keyword_pos + hl.todo_keyword:len() + 1
      end
      if hl.priority then
        hl.range.start_col = todo_keyword_pos + hl.start_col
        hl.range.end_col = todo_keyword_pos + hl.start_col + 4
      end
      return hl
    end, agenda_item.highlights)
  end

  if headline:is_clocked_in() then
    table.insert(item_highlights, {
      range = Range:new({
        start_line = line_nr + 1,
        end_line = line_nr + 1,
        start_col = 1,
        end_col = 0,
      }),
      hlgroup = 'Visual',
      whole_line = true,
    })
  end

  return {
    line_content = line,
    line = line_nr,
    jumpable = true,
    file = headline.file.filename,
    file_position = headline:get_range().start_line,
    highlights = item_highlights,
    longest_date = longest_date,
    longest_category = longest_category,
    agenda_item = agenda_item,
    headline = headline,
  }
end

function AgendaView:_format_day(day)
  return string.format('%-10s %s', day:format('%A'), day:format('%d %B %Y'))
end

return AgendaView

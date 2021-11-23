local Date = require('orgmode.objects.date')
local Range = require('orgmode.parser.range')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local colors = require('orgmode.colors')
local AgendaItem = require('orgmode.agenda.agenda_item')
local ClockReport = require('orgmode.clock.report')
local Calendar = require('orgmode.objects.calendar')
local agenda_highlights = require('orgmode.colors.highlights')
local Files = require('orgmode.parser.files')
local Search = require('orgmode.parser.search')
local AgendaFilter = require('orgmode.agenda.filter')
local hl_map = agenda_highlights.get_agenda_hl_map()

---@param agenda_items AgendaItem[]
---@return AgendaItem[]
local function sort_agenda_items(agenda_items)
  table.sort(agenda_items, function(a, b)
    -- if both are date only don't change their order
    if a.headline_date.date_only and b.headline_date.date_only then
      return false
    end
    -- date only items get sorted last
    if not a.headline_date.date_only and b.headline_date.date_only then
      return false
    end
    if a.headline_date.date_only and not b.headline_date.date_only then
      return true
    end

    if a.is_today and a.is_same_day then
      if b.is_today and b.is_same_day then
        return a.headline_date:is_before(b.headline_date)
      end
      return true
    end

    if b.is_today and b.is_same_day then
      if a.is_today and a.is_same_day then
        return a.headline_date:is_before(b.headline_date)
      end
      return false
    end

    if a.headline:get_priority_sort_value() ~= b.headline:get_priority_sort_value() then
      return a.headline:get_priority_sort_value() > b.headline:get_priority_sort_value()
    end

    if a.headline:has_priority() and b.headline:has_priority() then
      return a.headline_date:is_before(b.headline_date)
    end

    if a.is_in_date_range and not b.is_in_date_range then
      return false
    end

    if not a.is_in_date_range and b.is_in_date_range then
      return true
    end

    return a.headline_date:is_before(b.headline_date)
  end)
  return agenda_items
end

local function sort_todos(todos)
  table.sort(todos, function(a, b)
    if a:get_priority_sort_value() ~= b:get_priority_sort_value() then
      return a:get_priority_sort_value() > b:get_priority_sort_value()
    end
    return a.category < b.category
  end)
  return todos
end

---@class Agenda
---@field span string|number
---@field from Date
---@field to Date
---@field items table[]
---@field content table[]
---@field highlights table[]
---@field active_view string
---@field clock_report ClockReport
---@field show_clock_report boolean
---@field last_search string
---@field filters AgendaFilter
local Agenda = {}

---@param opts table
function Agenda:new(opts)
  opts = opts or {}
  local data = {
    span = config:get_agenda_span(),
    active_view = 'agenda',
    show_clock_report = false,
    clock_report = nil,
    last_search = '',
    filters = AgendaFilter:new(),
    content = {},
    highlights = {},
    items = {},
  }
  setmetatable(data, self)
  self.__index = self
  data:_set_date_range()
  return data
end

function Agenda:_get_title()
  local span = self.span
  if type(span) == 'number' then
    span = string.format('%d days', span)
  end
  local span_number = ''
  if span == 'week' then
    span_number = string.format(' (W%d)', self.from:get_week_number())
  end
  return utils.capitalize(span) .. '-agenda' .. span_number .. ':'
end

function Agenda:render_agenda()
  local content = { { line_content = self:_get_title() } }
  local highlights = {}
  for _, item in ipairs(self.items) do
    local day = item.day
    local agenda_items = item.agenda_items

    local is_today = day:is_today()
    local is_weekend = day:is_weekend()

    if is_today or is_weekend then
      table.insert(highlights, {
        hlgroup = 'OrgBold',
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
      acc.category = math.max(acc.category, agenda_item.headline:get_category():len())
      acc.label = math.max(acc.label, agenda_item.label:len())
      return acc
    end, {
      category = 0,
      label = 0,
    })
    local category_len = math.max(11, (longest_items.category + 1))
    local date_len = math.min(11, longest_items.label)

    for _, agenda_item in ipairs(agenda_items) do
      local headline = agenda_item.headline
      local category = string.format('  %-' .. category_len .. 's', headline:get_category() .. ':')
      local date = agenda_item.label
      if date ~= '' then
        date = string.format(' %-' .. date_len .. 's', agenda_item.label)
      end
      local todo_keyword = agenda_item.headline.todo_keyword.value
      local todo_padding = ''
      if todo_keyword ~= '' and vim.trim(agenda_item.label):find(':$') then
        todo_padding = ' '
      end
      todo_keyword = todo_padding .. todo_keyword
      local line = string.format('%s%s%s %s', category, date, todo_keyword, headline.title)
      local todo_keyword_pos = string.format('%s%s%s', category, date, todo_padding):len()
      if #headline.tags > 0 then
        line = string.format('%-99s %s', line, headline:tags_to_string())
      end

      local item_highlights = {}
      if #agenda_item.highlights then
        item_highlights = vim.tbl_map(function(hl)
          hl.range = Range:new({
            start_line = #content + 1,
            end_line = #content + 1,
            start_col = 1,
            end_col = 0,
          })
          if hl.todo_keyword then
            hl.range.start_col = todo_keyword_pos + 1
            hl.range.end_col = todo_keyword_pos + hl.todo_keyword:len() + 1
          end
          return hl
        end, agenda_item.highlights)
      end

      if headline:is_clocked_in() then
        table.insert(item_highlights, {
          range = Range:new({
            start_line = #content + 1,
            end_line = #content + 1,
            start_col = 1,
            end_col = 0,
          }),
          hl_group = 'Visual',
          whole_line = true,
        })
      end

      table.insert(content, {
        line_content = line,
        line = #content,
        jumpable = true,
        file = headline.file,
        file_position = headline.range.start_line,
        highlights = item_highlights,
        agenda_item = agenda_item,
        headline = headline,
      })
    end
  end

  self.content = content
  self.highlights = highlights
  self.active_view = 'agenda'
  if self.show_clock_report then
    self.clock_report = ClockReport.from_date_range(self.from, self.to)
    utils.concat(self.content, self.clock_report:draw_for_agenda(#self.content + 1))
  end
  return self:_print_and_highlight()
end

function Agenda:render_todos(view)
  self.items = sort_todos(self.items)
  local offset = #self.content
  local longest_category = utils.reduce(self.items, function(acc, todo)
    return math.max(acc, todo:get_category():len())
  end, 0)

  for i, headline in ipairs(self.items) do
    if self.filters:matches(headline) then
      table.insert(self.content, self:_generate_todo_item(headline, longest_category, i + offset))
    end
  end

  self.active_view = view
  return self:_print_and_highlight()
end

function Agenda:_generate_todo_item(headline, longest_category, line_nr)
  local category = string.format('  %-' .. (longest_category + 1) .. 's', headline:get_category() .. ':')
  local todo_keyword = headline.todo_keyword.value
  local todo_keyword_padding = todo_keyword ~= '' and ' ' or ''
  local line = string.format('  %s%s%s %s', category, todo_keyword_padding, todo_keyword, headline.title)
  if #headline.tags > 0 then
    line = string.format('%-99s %s', line, headline:tags_to_string())
  end
  local todo_keyword_pos = category:len() + 4
  local highlights = {}
  if headline.todo_keyword.value ~= '' then
    table.insert(highlights, {
      hlgroup = hl_map[headline.todo_keyword.value] or hl_map[headline.todo_keyword.type],
      range = Range:new({
        start_line = line_nr,
        end_line = line_nr,
        start_col = todo_keyword_pos,
        end_col = todo_keyword_pos + todo_keyword:len(),
      }),
    })
  end
  if headline:is_clocked_in() then
    table.insert(highlights, {
      range = Range:new({
        start_line = line_nr,
        end_line = line_nr,
        start_col = 1,
        end_col = 0,
      }),
      hl_group = 'Visual',
      whole_line = true,
    })
  end
  return {
    line_content = line,
    longest_category = longest_category,
    line = line_nr,
    jumpable = true,
    file = headline.file,
    file_position = headline.range.start_line,
    headline = headline,
    highlights = highlights,
  }
end

function Agenda:_print_and_highlight()
  local opened = self:is_opened()
  local win_height = math.max(math.min(34, #self.content), config.org_agenda_min_height)
  if not opened then
    vim.cmd(string.format('%dsplit orgagenda', win_height))
    vim.cmd([[setf orgagenda]])
    vim.cmd([[setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell]])
    config:setup_mappings('agenda')
  else
    vim.cmd(string.format('resize %d', win_height))
    vim.cmd(vim.fn.win_id2win(opened) .. 'wincmd w')
  end
  local lines = vim.tbl_map(function(item)
    return item.line_content
  end, self.content)
  vim.bo.modifiable = true
  vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
  vim.bo.modifiable = false
  vim.bo.modified = false
  colors.highlight(self.highlights, true)
  vim.tbl_map(function(item)
    if item.highlights then
      return colors.highlight(item.highlights)
    end
  end, self.content)
end

-- TODO: Introduce searching ALL/DONE
function Agenda:todos()
  self.items = {}
  for _, orgfile in ipairs(Files.all()) do
    for _, headline in ipairs(orgfile:get_unfinished_todo_entries()) do
      if self.filters:matches(headline) then
        table.insert(self.items, headline)
      end
    end
  end

  self.content = { { line_content = 'Global list of TODO items of type: ALL' } }
  self.highlights = {}
  self:render_todos('todos')
end

function Agenda:search(clear_search)
  if clear_search then
    self.last_search = ''
  end
  local search_term = self.last_search
  if not self.filters.applying then
    search_term = vim.fn.OrgmodeInput('Enter search term: ', self.last_search)
  end
  self.last_search = search_term
  self.items = Files.find_headlines_matching_search_term(search_term, false, true)
  if self.filters:should_filter() then
    self.items = vim.tbl_filter(function(item)
      return self.filters:matches(item)
    end, self.items)
  end

  self.content = {
    { line_content = 'Search words: ' .. search_term },
    { line_content = 'Press "r" to update search' },
  }
  self.highlights = {
    { hlgroup = 'Comment', range = Range.for_line_hl(1) },
    { hlgroup = 'Comment', range = Range.for_line_hl(2) },
  }

  return self:render_todos('search')
end

function Agenda:tags(opts)
  return self:_tags_view(opts, 'tags')
end

function Agenda:tags_todo(opts)
  opts = opts or {}
  opts.todo_only = true
  return self:_tags_view(opts, 'tags_todo')
end

function Agenda:_tags_view(opts, view)
  opts = opts or {}
  local tags = opts.tags

  if opts.clear_search then
    self.last_search = ''
  end

  if not tags then
    tags = vim.fn.OrgmodeInput('Match: ', self.last_search, Files.autocomplete_tags)
  end
  if vim.trim(tags) == '' then
    return utils.echo_warning('Invalid tag.')
  end
  local search = Search:new(tags)
  self.items = {}
  for _, orgfile in ipairs(Files.all()) do
    local headlines_filtered = orgfile:apply_search(search, opts.todo_only)
    for _, headline in ipairs(headlines_filtered) do
      if self.filters:matches(headline) then
        table.insert(self.items, headline)
      end
    end
  end

  self.last_search = tags
  self.content = {
    { line_content = 'Headlines with TAGS match: ' .. tags },
    { line_content = 'Press "r" to update search' },
  }
  self.highlights = {
    { hlgroup = 'Comment', range = Range.for_line_hl(1) },
    { hlgroup = 'Comment', range = Range.for_line_hl(2) },
  }

  return self:render_todos(view)
end

function Agenda:prompt()
  self.filters:reset()
  return utils.menu('Press key for an agenda command', {
    { label = '', separator = '-', length = 34 },
    {
      label = 'Agenda for current week or day',
      key = 'a',
      action = function()
        return self:agenda()
      end,
    },
    {
      label = 'List of all TODO entries',
      key = 't',
      action = function()
        return self:todos()
      end,
    },
    {
      label = 'Match a TAGS/PROP/TODO query',
      key = 'm',
      action = function()
        return self:tags({ clear_search = true })
      end,
    },
    {
      label = 'Like m, but only TODO entries',
      key = 'M',
      action = function()
        return self:tags_todo({ clear_search = true })
      end,
    },
    {
      label = 'Search for keywords',
      key = 's',
      action = function()
        return self:search(true)
      end,
    },
    { label = 'Quit', key = 'q' },
    { label = '', separator = ' ', length = 1 },
  }, 'Press key for an agenda command')
end

function Agenda:agenda()
  local dates = self.from:get_range_until(self.to)
  local agenda_days = {}

  local headline_dates = {}
  for _, orgfile in ipairs(Files.all()) do
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

    for _, item in ipairs(headline_dates) do
      local agenda_item = AgendaItem:new(item.headline_date, item.headline, day)
      if agenda_item.is_valid and self.filters:matches(item.headline) then
        table.insert(date.agenda_items, agenda_item)
      end
    end

    date.agenda_items = sort_agenda_items(date.agenda_items)

    table.insert(agenda_days, date)
  end

  self.items = agenda_days
  self:render_agenda()
  vim.fn.search(self:_format_day(Date.now()))
end

function Agenda:reset()
  if self.active_view ~= 'agenda' then
    return utils.echo_warning('Not possible in this view.')
  end
  self:_set_date_range()
  return self:agenda()
end

function Agenda:redo(preserve_cursor_pos)
  Files.load(vim.schedule_wrap(function()
    local view = nil
    if preserve_cursor_pos then
      view = vim.fn.winsaveview()
    end
    self[self.active_view](self)
    self.filters.applying = false
    if preserve_cursor_pos then
      vim.fn.winrestview(view)
    end
  end))
end

function Agenda:is_opened()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_buf_get_option(vim.api.nvim_win_get_buf(win), 'filetype') == 'orgagenda' then
      return win
    end
  end
  return false
end

function Agenda:advance_span(direction)
  if self.active_view ~= 'agenda' then
    return utils.echo_warning('Not possible in this view.')
  end
  local action = { [self.span] = direction }
  if type(self.span) == 'number' then
    action = { day = self.span * direction }
  end
  self.from = self.from:add(action)
  self.to = self.to:add(action)
  return self:agenda()
end

function Agenda:change_span(span)
  if self.active_view ~= 'agenda' then
    return utils.echo_warning('Not possible in this view.')
  end
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
  return self:agenda()
end

function Agenda:open_day(day)
  self.active_view = 'agenda'
  self.span = 'day'
  self:_set_date_range(day)
  self:agenda()
  return vim.fn.search(self:_format_day(day))
end

function Agenda:goto_date()
  return Calendar.new({ date = Date.now() }).open():next(function(date)
    if not date then
      return
    end
    self:_set_date_range(date)
    self:agenda()
    return vim.fn.search(self:_format_day(date))
  end)
end

function Agenda:switch_to_item()
  local item = self:_get_jumpable_item()
  if not item then
    return
  end
  vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
  vim.fn.cursor(item.file_position, 0)
end

function Agenda:change_todo_state()
  return self:_remote_edit({
    action = 'org_mappings.todo_next_state',
    update_in_place = true,
  })
end

function Agenda:clock_in()
  return self:_remote_edit({
    action = 'clock.org_clock_in',
    redo = true,
  })
end

function Agenda:clock_out()
  return self:_remote_edit({
    action = 'clock.org_clock_out',
    redo = true,
    getter = function()
      local last_clocked = Files.get_clocked_headline()
      if last_clocked and last_clocked:is_clocked_in() then
        return { file = last_clocked.file, file_position = last_clocked.range.start_line }
      end
    end,
  })
end

function Agenda:clock_cancel()
  return self:_remote_edit({
    action = 'clock.org_clock_cancel',
    redo = true,
    getter = function()
      local last_clocked = Files.get_clocked_headline()
      if last_clocked and last_clocked:is_clocked_in() then
        return { file = last_clocked.file, file_position = last_clocked.range.start_line }
      end
    end,
  })
end

function Agenda:set_effort()
  return self:_remote_edit({ action = 'clock.org_set_effort' })
end

function Agenda:set_priority()
  return self:_remote_edit({
    action = 'org_mappings.set_priority',
    update_in_place = true,
  })
end

function Agenda:priority_up()
  return self:_remote_edit({
    action = 'org_mappings.priority_up',
    update_in_place = true,
  })
end

function Agenda:priority_down()
  return self:_remote_edit({
    action = 'org_mappings.priority_down',
    update_in_place = true,
  })
end

function Agenda:toggle_archive_tag()
  return self:_remote_edit({
    action = 'org_mappings.toggle_archive_tag',
    update_in_place = true,
  })
end

function Agenda:set_tags()
  return self:_remote_edit({
    action = 'org_mappings.set_tags',
    update_in_place = true,
  })
end

function Agenda:set_deadline()
  return self:_remote_edit({
    action = 'org_mappings.org_deadline',
    redo = true,
  })
end

function Agenda:set_schedule()
  return self:_remote_edit({
    action = 'org_mappings.org_schedule',
    redo = true,
  })
end

function Agenda:toggle_clock_report()
  if self.active_view ~= 'agenda' then
    return utils.warning('Not possible to view clock report in non-agenda view.')
  end
  self.show_clock_report = not self.show_clock_report
  local text = self.show_clock_report and 'on' or 'off'
  utils.echo_info(string.format('Clocktable mode is %s', text))
  return self:redo(true)
end

function Agenda:goto_item()
  local item = self:_get_jumpable_item()
  if not item then
    return
  end
  local target_window = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_buf_get_option(vim.api.nvim_win_get_buf(win), 'filetype') == 'org' then
      target_window = win
    end
  end

  if not target_window then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_get_option(buf, 'buftype') == '' and vim.api.nvim_buf_get_option(buf, 'modifiable') then
        target_window = win
      end
    end
  end

  if target_window then
    vim.cmd(vim.fn.win_id2win(target_window) .. 'wincmd w')
  else
    vim.cmd([[aboveleft split]])
  end

  vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
  vim.fn.cursor(item.file_position, 0)
end

function Agenda:filter()
  local this = self
  self.filters:parse_tags_and_categories(self.content)
  local filter_term = vim.fn.OrgmodeInput('Filter [+cat-tag/regexp/]: ', self.filters.value, function(arg_lead)
    return utils.prompt_autocomplete(arg_lead, this.filters:get_completion_list(), { '+', '-' })
  end)
  self.filters:parse(filter_term)
  return self:redo()
end

---@param opts table
function Agenda:_remote_edit(opts)
  opts = opts or {}
  local line = vim.fn.line('.')
  local action = opts.action
  if not action then
    return
  end
  local getter = opts.getter
    or function()
      local item = self.content[line]
      if not item or not item.jumpable then
        return
      end
      return item
    end
  local item = getter()
  if not item then
    return
  end
  local update = Files.update_file(item.file, function(_)
    vim.fn.cursor(item.file_position, 0)
    return utils.promisify(require('orgmode').action(action)):next(function()
      return Files.get_closest_headline()
    end)
  end)

  update:next(function(headline)
    if opts.redo then
      return self:redo(true)
    end
    if not opts.update_in_place or not headline then
      return
    end
    if self.active_view == 'agenda' and item.agenda_item then
      item.agenda_item:set_headline(headline)
      return self:render_agenda()
    end
    self.content[line] = self:_generate_todo_item(headline, item.longest_category, item.line)
    return self:_print_and_highlight()
  end)
end

---@return table|nil
function Agenda:_get_jumpable_item()
  local item = self.content[vim.fn.line('.')]
  if not item then
    return nil
  end
  if item.is_table and item.table_row and self.clock_report then
    item = self.clock_report:find_agenda_item(item)
  end
  if not item.jumpable then
    return nil
  end
  return item
end

function Agenda:_set_date_range(from)
  local span = self.span
  from = from or Date.now():start_of('day')
  local is_week = span == 'week' or span == '7'
  if is_week and config.org_agenda_start_on_weekday then
    from = from:set_isoweekday(config.org_agenda_start_on_weekday)
  end
  local to = nil
  local modifier = { [span] = 1 }
  if type(span) == 'number' then
    modifier = { day = span }
  end

  to = from:add(modifier)

  if config.org_agenda_start_day and type(config.org_agenda_start_day) == 'string' then
    from = from:adjust(config.org_agenda_start_day)
    to = to:adjust(config.org_agenda_start_day)
  end

  self.span = span
  self.from = from
  self.to = to
end

function Agenda:quit()
  vim.cmd([[bw!]])
end

function Agenda:_format_day(day)
  return string.format('%-10s %s', day:format('%A'), day:format('%d %B %Y'))
end

return Agenda

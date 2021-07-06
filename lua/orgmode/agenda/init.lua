local Date = require('orgmode.objects.date')
local Range = require('orgmode.parser.range')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local colors = require('orgmode.colors')
local AgendaItem = require('orgmode.agenda.agenda_item')
local Calendar = require('orgmode.objects.calendar')
local agenda_highlights = require('orgmode.colors.highlights')
local Files = require('orgmode.parser.files')
local Search = require('orgmode.parser.search')
local hl_map = agenda_highlights.get_agenda_hl_map()

---@param agenda_items AgendaItem[]
---@return AgendaItem[]
local function sort_agenda_items(agenda_items)
  table.sort(agenda_items, function(a, b)
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

    if a.headline:get_priority_number() ~= b.headline:get_priority_number() then
      return a.headline:get_priority_number() > b.headline:get_priority_number()
    end

    if a.headline:has_priority() and b.headline:has_priority() then
      return a.headline_date:is_before(b.headline_date)
    end

    if a.headline.category ~= b.headline.category then
      return a.headline.category < b.headline.category
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

---@class Agenda
---@field span string|number
---@field from Date
---@field to Date
---@field items table[]
---@field content table[]
---@field highlights table[]
---@field active_view string
---@field last_search string
local Agenda = {}

---@param opts table
function Agenda:new(opts)
  opts = opts or {}
  local data = {
    span = config:get_agenda_span(),
    active_view = 'agenda',
    last_search = '',
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
  return utils.capitalize(span)..'-agenda'..span_number..':'
end

function Agenda:render()
  local content = { { line_content = self:_get_title() } }
  local highlights = {}
  for _ , item in ipairs(self.items) do
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
          end_col = 0
        }),
      })
    end

    table.insert(content, { line_content = self:_format_day(day) })

    local longest_items = utils.reduce(agenda_items, function(acc, agenda_item)
      acc.category = math.max(acc.category, agenda_item.headline:get_category():len())
      acc.label = math.max(acc.label, agenda_item.label:len())
      return acc
    end, { category = 0, label = 0 })
    local category_len = math.max(11, (longest_items.category + 1))
    local date_len = math.min(11, longest_items.label)

    for _, agenda_item in ipairs(agenda_items) do
      local headline = agenda_item.headline
      local category = string.format('  %-'..category_len..'s', headline:get_category()..':')
      local date = agenda_item.label
      if date ~= '' then
        date = string.format(' %-'..date_len..'s', agenda_item.label)
      end
      local todo_keyword = agenda_item.headline.todo_keyword.value
      local todo_padding = ''
      if todo_keyword ~= '' and vim.trim(agenda_item.label):find(':$') then
        todo_padding = ' '
      end
      todo_keyword = todo_padding..todo_keyword
      local line = string.format(
        '%s%s%s %s', category, date, todo_keyword, headline.title
      )
      local todo_keyword_pos = string.format('%s%s%s', category, date, todo_padding):len()
      if #headline.tags > 0 then
        line = string.format('%-99s %s', line, headline:tags_to_string())
      end

      if #agenda_item.highlights then
        utils.concat(highlights, vim.tbl_map(function(hl)
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
        end, agenda_item.highlights))
      end

      table.insert(content, {
        line_content = line,
        line = #content,
        jumpable = true,
        file = headline.file,
        file_position = headline.range.start_line
      })
    end
  end

  self.content = content
  self.highlights = highlights
  self.active_view = 'agenda'
  return self:_print_and_highlight()
end

function Agenda:_print_and_highlight()
  local opened = self:is_opened()
  local win_height = math.max(math.min(34, #self.content), 16)
  if not opened then
    vim.cmd(string.format('%dsplit orgagenda', win_height))
    vim.cmd[[setf orgagenda]]
    vim.cmd[[setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell]]
    config:setup_mappings('agenda')
  else
    vim.cmd(string.format('resize %d', win_height))
    vim.cmd(vim.fn.win_id2win(opened)..'wincmd w')
  end
  vim.bo.modifiable = true
  local lines = vim.tbl_map(function(item)
    return item.line_content
  end, self.content)
  vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
  vim.bo.modifiable = false
  vim.bo.modified = false
  colors.highlight(self.highlights)
end

-- TODO: Introduce searching ALL/DONE
function Agenda:todos()
  local todos = {}
  for _, orgfile in ipairs(Files.all()) do
    for _, headline in ipairs(orgfile:get_unfinished_todo_entries()) do
      table.insert(todos, headline)
    end
  end

  local longest_category = utils.reduce(todos, function(acc, todo)
    return math.max(acc, todo:get_category():len())
  end, 0)

  local content = {{ line_content = 'Global list of TODO items of type: ALL', highlight = nil }}
  local highlights = {}

  for i, todo in ipairs(todos) do
    local category = string.format('  %-'..(longest_category + 1)..'s', todo:get_category()..':')
    local todo_keyword = todo.todo_keyword.value
    local line = string.format('  %s %s %s', category, todo_keyword, todo.title)
    if #todo.tags > 0 then
      line = string.format('%-99s %s', line, todo:tags_to_string())
    end
    local todo_keyword_pos = category:len() + 4
    table.insert(content, {
      line_content = line,
      line = i + 1,
      jumpable = true,
      file = todo.file,
      file_position = todo.range.start_line
    })

    if todo.todo_keyword.value ~= '' then
      table.insert(highlights, {
        hlgroup = hl_map[todo.todo_keyword.value] or hl_map[todo.todo_keyword.type],
        range = Range:new({
          start_line = i + 1,
          end_line = i + 1,
          start_col = todo_keyword_pos,
          end_col = todo_keyword_pos + todo_keyword:len()
        })
      })
    end
  end

  self.content = content
  self.highlights = highlights
  self.active_view = 'todos'
  return self:_print_and_highlight()
end

function Agenda:search(clear_search)
  if clear_search then
    self.last_search = ''
  end
  local search_term = vim.fn.input('Enter search term: ', self.last_search)
  self.last_search = search_term
  local headlines = Files.find_headlines_matching_search_term(search_term)

  local longest_category = utils.reduce(headlines, function(acc, todo)
    return math.max(acc, todo:get_category():len())
  end, 0)

  local content = {
    { line_content = 'Search words: '..search_term },
    { line_content = 'Press "r" to update search' }
  }
  local highlights = {
    { hlgroup = 'Comment', range = Range.for_line_hl(1) },
    { hlgroup = 'Comment', range = Range.for_line_hl(2) },
  }

  for i, headline in ipairs(headlines) do
    local category = string.format('  %-'..(longest_category + 1)..'s', headline:get_category()..':')
    local todo_keyword = headline.todo_keyword.value
    local todo_keyword_padding = todo_keyword ~= '' and ' ' or ''
    local line = string.format('  %s%s%s %s', category, todo_keyword_padding, todo_keyword, headline.title)
    if #headline.tags > 0 then
      line = string.format('%-99s %s', line, headline:tags_to_string())
    end
    table.insert(content, {
      line_content = line,
      line = i + 2,
      jumpable = true,
      file = headline.file,
      file_position = headline.range.start_line
    })

    if headline.todo_keyword.value ~= '' then
      local todo_keyword_pos = category:len() + 4
      table.insert(highlights, {
        hlgroup = hl_map[headline.todo_keyword.value] or hl_map[headline.todo_keyword.type],
        range = Range:new({
          start_line = i + 2,
          end_line = i + 2,
          start_col = todo_keyword_pos,
          end_col = todo_keyword_pos + todo_keyword:len()
        })
      })
    end
  end

  self.content = content
  self.highlights = highlights
  self.active_view = 'search'
  return self:_print_and_highlight()
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
    tags = vim.fn.input('Match: ', self.last_search, 'customlist,v:lua.orgmode.autocomplete_agenda_filter_tags')
  end
  if vim.trim(tags) == '' then
    return utils.echo_warning('Invalid tag.')
  end
  local search = Search:new(tags)
  local headlines = {}
  for _, orgfile in ipairs(Files.all()) do
    local headlines_filtered = orgfile:apply_search(search, opts.todo_only)
    for _, headline in ipairs(headlines_filtered) do
      table.insert(headlines, headline)
    end
  end

  local longest_category = utils.reduce(headlines, function(acc, todo)
    return math.max(acc, todo:get_category():len())
  end, 0)

  self.last_search = tags
  local content = {
    { line_content = 'Headlines with TAGS match: '..tags },
    { line_content = 'Press "r" to update search' },
  }
  local highlights = {
    { hlgroup = 'Comment', range = Range.for_line_hl(1) },
    { hlgroup = 'Comment', range = Range.for_line_hl(2) },
  }

  for i, headline in ipairs(headlines) do
    local category = string.format('  %-'..(longest_category + 1)..'s', headline:get_category()..':')
    local todo_keyword = headline.todo_keyword.value
    local todo_keyword_padding = todo_keyword ~= '' and ' ' or ''
    local line = string.format('  %s%s%s %s', category, todo_keyword_padding, todo_keyword, headline.title)
    if #headline.tags > 0 then
      line = string.format('%-99s %s', line, headline:tags_to_string())
    end
    table.insert(content, {
      line_content = line,
      line = i + 2,
      jumpable = true,
      file = headline.file,
      file_position = headline.range.start_line
    })

    if headline.todo_keyword.value ~= '' then
      local todo_keyword_pos = category:len() + 4
      table.insert(highlights, {
        hlgroup = hl_map[headline.todo_keyword.value] or hl_map[headline.todo_keyword.type],
        range = Range:new({
          start_line = i + 2,
          end_line = i + 2,
          start_col = todo_keyword_pos,
          end_col = todo_keyword_pos + todo_keyword:len()
        })
      })
    end
  end

  self.content = content
  self.highlights = highlights
  self.active_view = view
  return self:_print_and_highlight()
end

function Agenda:prompt()
  return utils.menu('Press key for an agenda command', {
    { label = '', separator = '-', length = 34 },
    { label = 'Agenda for current week or day', key = 'a', action = function() return self:agenda() end },
    { label = 'List of all TODO entries', key = 't', action = function() return self:todos() end },
    { label = 'Match a TAGS/PROP/TODO query', key = 'm', action = function() return self:tags({ clear_search = true }) end },
    { label = 'Like m, but only TODO entries', key = 'M', action = function() return self:tags_todo({ clear_search = true }) end },
    { label = 'Search for keywords', key = 's', action = function() return self:search(true) end },
    { label = 'Quit', key = 'q' },
    { label = '', separator = ' ', length = 1 },
  }, 'Press key for an agenda command')
end

function Agenda:agenda()
  local dates = self.from:get_range_until(self.to)
  local agenda_days = {}

  for _, day in ipairs(dates) do
    local date = { day = day, agenda_items = {} }

    for _, orgfile in ipairs(Files.all()) do
      for _, headline in ipairs(orgfile:get_opened_headlines()) do
        for _, headline_date in ipairs(headline:get_valid_dates_for_agenda()) do
          local item = AgendaItem:new(headline_date, headline, day)
          if item.is_valid then
            table.insert(date.agenda_items, item)
          end
        end
      end
    end

    date.agenda_items = sort_agenda_items(date.agenda_items)

    table.insert(agenda_days, date)
  end

  self.items = agenda_days
  self:render()
  vim.fn.search(self:_format_day(Date.now()))
end

function Agenda:reset()
  if self.active_view ~= 'agenda' then
    return utils.echo_warning('Not possible in this view.')
  end
  self:_set_date_range()
  return self:agenda()
end

function Agenda:redo()
  Files.load(vim.schedule_wrap(function()
    self[self.active_view](self)
  end))
end

function Agenda:is_opened()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_buf_get_option(vim.api.nvim_win_get_buf(win),'filetype') == 'orgagenda' then
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
  if span == self.span then return end
  if span == 'year' then
    local c = vim.fn.confirm('Are you sure you want to print agenda for the whole year?', '&Yes\n&No')
    if c ~= 1 then return end
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
  local cb = function(date)
    self:_set_date_range(date)
    self:agenda()
    return vim.fn.search(self:_format_day(date))
  end
  Calendar.new({ callback = cb, date = Date.now() }).open()
end

function Agenda:switch_to_item()
  local item = self.content[vim.fn.line('.')]
  if not item or not item.jumpable then return end
  vim.cmd('edit '..vim.fn.fnameescape(item.file))
  vim.fn.cursor(item.file_position, 0)
end

function Agenda:goto_item()
  local item = self.content[vim.fn.line('.')]
  if not item or not item.jumpable then return end
  local target_window = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_buf_get_option(vim.api.nvim_win_get_buf(win),'filetype') == 'org' then
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
    vim.cmd(vim.fn.win_id2win(target_window)..'wincmd w')
  else
    vim.cmd[[aboveleft split]]
  end

  vim.cmd('edit '..vim.fn.fnameescape(item.file))
  vim.fn.cursor(item.file_position, 0)
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
  vim.cmd[[bw!]]
end

function Agenda:_format_day(day)
  return string.format('%-10s %s', day:format('%A'), day:format('%d %B %Y'))
end

function _G.orgmode.autocomplete_agenda_filter_tags(arg_lead)
  return Files.autocomplete_tags(arg_lead)
end

return Agenda

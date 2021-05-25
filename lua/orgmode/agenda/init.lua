local Date = require('orgmode.objects.date')
local Range = require('orgmode.parser.range')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local colors = require('orgmode.colors')
local AgendaItem = require('orgmode.agenda.agenda_item')

---@class Agenda
---@field files Root[]
---@field org Org
---@field span string|number
---@field day_format string
---@field items table[]
---@field content string[]
local Agenda = {}

---@param opts table
function Agenda:new(opts)
  opts = opts or {}
  local data = {
    org = opts.org,
    files = opts.files or {},
    span = config:get_agenda_span(),
    day_format = '%A %d %B %Y',
    content = {},
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

    table.insert(content, { line_content = day:format(self.day_format) })

    local longest_items = utils.reduce(agenda_items, function(acc, agenda_item)
      acc.category = math.max(acc.category, agenda_item.headline.category:len())
      acc.label = math.max(acc.label, agenda_item.label:len())
      return acc
    end, { category = 0, label = 0 })

    for _, agenda_item in ipairs(agenda_items) do
      local headline = agenda_item.headline
      local category = string.format('  %-'..(longest_items.category + 1)..'s', headline.category..':')
      local date = agenda_item.label
      if date ~= '' then
        date = string.format(' %'..(longest_items.label)..'s', agenda_item.label)
      end
      local todo_keyword = agenda_item.headline.todo_keyword.value
      if todo_keyword ~= '' then
        todo_keyword = ' '..todo_keyword
      end
      local line = string.format(
        '%s%s%s %s', category, date, todo_keyword, headline.title
      )
      local todo_keyword_pos = string.format('%s%s ', category, date):len()
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
            hl.range.start_col = todo_keyword_pos
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
  local opened = self:is_opened()
  if not opened then
    vim.cmd[[16split orgagenda]]
    vim.cmd[[setf orgagenda]]
    vim.cmd[[setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell]]
    config:setup_mappings('agenda')
  else
    vim.cmd(vim.fn.win_id2win(opened)..'wincmd w')
  end
  vim.bo.modifiable = true
  local lines = vim.tbl_map(function(item)
    return item.line_content
  end, self.content)
  vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
  vim.bo.modifiable = false
  vim.bo.modified = false
  colors.highlight(highlights)
end

function Agenda:todos()
  local todos = {}
  for _, orgfile in pairs(self.files) do
    for _, headline in ipairs(orgfile:get_unfinished_todo_entries()) do
      table.insert(todos, headline)
    end
  end

  local longest_category = utils.reduce(todos, function(acc, todo)
    return math.max(acc, todo.category:len())
  end, 0)

  local content = {{ line_content = 'Global list of TODO items of type: ALL', highlight = nil }}
  local highlights = {}

  for i, todo in ipairs(todos) do
    local category = string.format('  %-'..(longest_category + 1)..'s', todo.category..':')
    local todo_keyword = todo.todo_keyword.value
    local line = string.format('  %s %s %s', category, todo_keyword, todo.title)
    if #todo.tags > 0 then
      line = string.format('%-99s %s', line, todo:tags_to_string())
    end
    local todo_keyword_pos = category:len() + 3
    table.insert(content, {
      line_content = line,
      value = todo,
      id = todo.id,
    })

    table.insert(highlights, {
      hlgroup = 'OrgTODO',
      range = Range:new({
        start_line = i + 1,
        end_line = i + 1,
        start_col = todo_keyword_pos,
        end_col = todo_keyword_pos + todo_keyword:len() + 1
      })
    })
  end

  self.content = content
  local opened = self:is_opened()
  if not opened then
    vim.cmd[[16split orgagenda]]
    vim.cmd[[setf orgagenda]]
    vim.cmd[[setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell]]
    config:setup_mappings('agenda')
  else
    vim.cmd(vim.fn.win_id2win(opened)..'wincmd w')
  end
  vim.bo.modifiable = true
  local lines = vim.tbl_map(function(item)
    return item.line_content
  end, self.content)
  vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
  vim.bo.modifiable = false
  vim.bo.modified = false
  colors.highlight(highlights)
end

function Agenda:prompt()
  return utils.menu('Press key for an agenda command:', {
    { label = '', separator = '-', length = 34 },
    { label = 'Agenda for current week or day', key = 'a', action = function() return self:open() end },
    { label = 'List of all TODO entries', key = 't', action = function() return self:todos() end },
    { label = 'Quit', key = 'q' },
    { label = '', separator = ' ', length = 1 },
  }, 'Press key for an agenda command:')
end

function Agenda:open()
  local dates = self.from:get_range_until(self.to)
  local agenda_days = {}

  for _, day in ipairs(dates) do
    local date = { day = day, agenda_items = {} }

    for _, orgfile in pairs(self.files) do
      for _, headline in ipairs(orgfile:get_opened_headlines()) do
        for _, headline_date in ipairs(headline:get_valid_dates()) do
          local item = AgendaItem:new(headline_date, headline, day)
          if item.is_valid then
            table.insert(date.agenda_items, item)
          end
        end
      end
    end

    -- TODO: Sort dates
    -- day.headlines = sort_headlines(day.headlines)

    table.insert(agenda_days, date)
  end

  self.items = agenda_days
  self:render()
  vim.fn.search(Date.now():format(self.day_format))
end

function Agenda:reset()
  self:_set_date_range()
  return self:open()
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
  local action = { [self.span] = direction }
  if type(self.span) == 'number' then
    action = { day = self.span * direction }
  end
  self.from = self.from:add(action)
  self.to = self.to:add(action)
  return self:open()
end

function Agenda:change_span(span)
  if span == self.span then return end
  if span == 'year' then
    local c = vim.fn.confirm('Are you sure you want to print agenda for the whole year?', '&Yes\n&No')
    if c ~= 1 then return end
  end
  self.span = span
  self:_set_date_range()
  return self:open()
end

function Agenda:select_item()
  local item = self.content[vim.fn.line('.')]
  if not item or not item.jumpable then return end
  vim.cmd('edit '..vim.fn.fnameescape(item.file))
  vim.fn.cursor(item.file_position, 0)
end

-- Items for today:
-- * Deadline for today
-- * Schedule for today (green)
-- * Schedule for past (orange) with counter in days
-- * Scheduled with delay (appears after the date, considers original date for counter)
-- * Overdue deadlines by num of days
-- * Future deadlines (consider warnings)
-- * Plain dates on the same day
-- ** Consider date range
-- ** Repaters
--
-- Items for non todays date
-- * Deadline for day (ignore warnings)
-- * Schedule for day (do not show if it has a delay)
-- * Plain date for day

function Agenda:_set_date_range()
  local span = self.span
  local from = Date.now():start_of('day')
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

return Agenda

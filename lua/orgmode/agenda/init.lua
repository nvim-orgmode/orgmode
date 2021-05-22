local Date = require('orgmode.objects.date')
local Types = require('orgmode.parser.types')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local colors = require('orgmode.colors')
local Agenda = {}
local keyword_hl_map = colors.get_agenda_hl_map()

---@class Agenda
---@param opts table
function Agenda:new(opts)
  opts = opts or {}
  local data = {
    files = opts.files or {},
    span = config:get_agenda_span(),
    day_format = '%A %d %B %Y',
    content = {}
  }
  setmetatable(data, self)
  self.__index = self
  data:_set_date_range()
  return data
end

function Agenda:render()
  local dates = self.from:get_range_until(self.to)
  local span = self.span
  if type(span) == 'number' then
    span = string.format('%d days', span)
  end
  local span_number = ''
  if span == 'week' then
    span_number = string.format(' (W%d)', self.from:get_week_number())
  end
  local content = {{ value = utils.capitalize(span)..'-agenda'..span_number..':' }}
  for _, date in ipairs(dates) do
    local date_string = date:format(self.day_format)
    local is_today = date:is_today()
    local is_weekend = date:is_weekend()
    local day_highlights = {}

    if is_today or is_weekend then
      day_highlights = {{ hlgroup = 'OrgBold', line = #content, from = 0, to = -1 }}
    end

    table.insert(content, { value = date_string, highlights = day_highlights })
    local day_dates = {}

    if is_today then
      for _, orgfile in pairs(self.files) do
        utils.concat(day_dates, self:get_headlines_for_today(orgfile, date))
      end
    else
      for _, orgfile in pairs(self.files) do
        utils.concat(day_dates, self:get_headlines_for_date(orgfile, date))
      end
    end
    Agenda:_map_to_content(day_dates, content)
  end

  self.content = content
  local opened = self:is_opened()
  if not opened then
    vim.cmd[[16split orgagenda]]
    vim.cmd[[setf orgagenda]]
    vim.cmd[[setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap nospell]]
  else
    vim.cmd(vim.fn.win_id2win(opened)..'wincmd w')
  end
  vim.bo.modifiable = true
  local lines = self:_generate_agenda_lines()
  vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
  vim.bo.modifiable = false
  vim.bo.modified = false
  for _, item in ipairs(content) do
    if item.highlights and #item.highlights > 0 then
      colors.highlight(item.highlights)
    end
  end
end

function Agenda:_generate_agenda_lines()
  local longest_category = utils.reduce(self.content, function(acc, item)
    if item.id then
      return math.max(acc, item.value.category:len())
    end
    return acc
  end, 0)
  local lines = {}
  for lnum, item in ipairs(self.content) do
    local val = item.value
    local line = val
    if item.id then
      local category = string.format('  %-'..(longest_category + 1)..'s', val.category..':')
      local date = string.format('%-9s', item.date_label)
      line = string.format(
        '%s %s %s %s', category, date, val.todo_keyword.value, val.title
      )
      if #val.tags > 0 then
        line = string.format('%-99s %s', line, val:tags_to_string())
      end

      if val.todo_keyword.range then
        local col_start = #string.format('%s %s ', category, date)
        local col_end = col_start + #val.todo_keyword.value
        table.insert(item.highlights, {
          line = lnum - 1,
          hlgroup = keyword_hl_map[val.todo_keyword.value],
          from = col_start,
          to = col_end
        })
      end
    end
    table.insert(lines, line)
  end
  return lines
end

function Agenda:_map_to_content(dates, content)
  dates = utils.sort_dates(dates)

  for _, date in ipairs(dates) do
    local highlights = {}
    if date.hlgroup then
      highlights = {{ hlgroup = date.hlgroup, line = #content, from = 0, to = -1  }}
    end
    table.insert(content, {
      value = date.headline,
      date_label = date.label,
      id = date.headline.id,
      highlights = highlights
    })
  end
end

function Agenda:open()
  self:render()
  vim.fn.search(Date.now():format(self.day_format))
end

function Agenda:reset()
  self:_set_date_range()
  self:render()
  vim.fn.search(Date.now():format(self.day_format))
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
  return self:render()
end

function Agenda:change_span(span)
  if span == self.span then return end
  if span == 'year' then
    local c = vim.fn.confirm('Are you sure you want to print agenda for the whole year?', '&Yes\n&No')
    if c ~= 1 then return end
  end
  self.span = span
  self:_set_date_range()
  self:render()
  vim.fn.search(Date.now():format(self.day_format))
end

function Agenda:select_item()
  local item = self.content[vim.fn.line('.')]
  if not item or not item.id then return end
  vim.cmd('edit '..item.value.file)
  vim.fn.cursor(item.value.range.start_line, 0)
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
---@param orgfile Root
---@param today Date
---@return table
function Agenda:get_headlines_for_today(orgfile, today)
  local headlines = orgfile:get_headlines_for_today()
  local result = {}

  for _, headline in ipairs(headlines) do
    for _, date in ipairs(headline:get_valid_dates()) do
      if date:is_valid_for_today(today) then
        local hlgroup = nil
        local label = date:humanize(today)
        local is_same_day = date:is_same(today, 'day')
        local print_time = true

        if date:is_deadline() then
          hlgroup = keyword_hl_map.deadline
          if is_same_day then
            label = 'Deadline'
          end
          if date:is_before(today, 'day') then
            print_time = false
          end
          if date:is_after(today, 'day') and date:diff(today) <= 7 then
            hlgroup = keyword_hl_map.scheduledPast
          end
        elseif date:is_scheduled() then
          hlgroup = keyword_hl_map.scheduled
          if is_same_day then
            label = 'Scheduled'
          end
          if date:is_before(today, 'day')
            or (date:get_warning_adjustment() and date:get_warning_date():is_same_or_before(today, 'day')) then
            label = 'Sched. '..today:diff(date)..'x'
            print_time = false
            hlgroup = keyword_hl_map.scheduledPast
          end
        else
          if label == 'Today' then
            label = ''
          end
        end
        local time = date:format_time()
        if print_time and time ~= '' then
          label = time..'...... '..label
        end

        table.insert(result, { date = date, label = label, headline = headline, hlgroup = hlgroup })
      end
    end
  end

  return result
end

-- Items for non todays date
-- * Deadline for day (ignore warnings)
-- * Schedule for day (do not show if it has a delay)
-- * Plain date for day
function Agenda:get_headlines_for_date(orgfile, date)
local headlines = orgfile:get_opened_headlines()
  local result = {}

  for _, headline in ipairs(headlines) do
    for _, d in ipairs(headline:get_valid_dates()) do
      if d:is_valid_for_date(date) then
        local label = ''
        local hlgroup = nil
        if d:is_deadline() then
          hlgroup = keyword_hl_map.deadline
          label = label..' Deadline'
          if d:is_past() and headline:is_done() then
            hlgroup = keyword_hl_map.scheduled
          end
        elseif d:is_scheduled() then
          hlgroup = keyword_hl_map.scheduled
          label = label..' Scheduled'
          if d:is_past() then
            hlgroup = keyword_hl_map.scheduledPast
          end
        end
        local time = d:format_time()
        if time ~= '' then
          label = time..'...... '..label
        end
        table.insert(result, { date = d, label = label, headline = headline, hlgroup = hlgroup })
      end
    end
  end

  return result
end

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

return Agenda

local Date = require('orgmode.objects.date')
local Types = require('orgmode.parser.types')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local Agenda = {}
local keyword_hl_map = {
  TODO = 'OrgTodo',
  NEXT = 'OrgNext',
  DONE = 'OrgDone',
}

---TODO: Move to utils and add test
---@param dates Date[]
---@return Date[]
local function sort_dates(dates)
  table.sort(dates, function(a, b)
    if a:is_deadline() then
      if not b:is_deadline() then return true end
      return a:is_before(b)
    end
    if b:is_deadline() then
      if not a:is_deadline() then return false end
      return a:is_before(b)
    end

    if a:is_scheduled() then
      if not b:is_scheduled() then return true end
      return a:is_before(b)
    end
    if b:is_scheduled() then
      if not a:is_scheduled() then return false end
      return a:is_before(b)
    end

    return a:is_before(b)
  end)
  return dates
end

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
  local content = {{ value = utils.capitalize(span)..'-agenda:' }}
  for _, date in ipairs(dates) do
    local date_string = date:format(self.day_format)
    local is_today = date:is_today()
    local is_weekend = date:is_weekend()
    local day_highlights = {}

    if is_today or is_weekend then
      table.insert(day_highlights, { hlgroup = 'OrgBold', line = #content, from = 0, to = -1 })
    end

    table.insert(content, { value = date_string, highlights = day_highlights })
    for filename, orgfile in pairs(self.files) do
      local headlines = {}
      if is_today then
        headlines = self:get_headlines_for_today(orgfile, date)
      else
        headlines = self:get_headlines_for_date(orgfile, date)
      end
      local longest_category = utils.reduce(headlines, function(acc, item)
        return math.max(acc, #item.headline.category)
      end, 0)
      for _, item in ipairs(headlines) do
        local sorted_dates = sort_dates(item.dates)
        local tags = ''
        if #item.headline.tags > 0 then
          tags = ':'..table.concat(item.headline.tags, ':')..':'
        end
        local category = string.format('  %-'..(longest_category - #item.headline.category)..'s:', item.headline.category)

        for _, d in ipairs(sorted_dates) do
          local date_label = d:humanize(date)
          local is_same_day = d:is_same(date, 'day')
          local highlights = {}
          local hlgroup = nil
          if d:is_deadline() then
            hlgroup = 'OrgAgendaDeadline'
            if is_same_day then
              date_label = 'Deadline'
              if not d.date_only and is_today then
                date_label = d:format('%H:%M')..'...... Deadline'
              end
            end
          elseif d:is_scheduled() and is_same_day then
            date_label = 'Scheduled'
            if not d.date_only and is_today then
              date_label = d:format('%H:%M')..'...... Scheduled'
            end
            local n = Date.now()
            if date:is_before(n, 'day') then
              if is_today then
                local diff = n:diff(date)
                date_label = 'Sched. '..diff..'x'
              end
              hlgroup = 'OrgAgendaSchedulePast'
            elseif date:is_after(n, 'day') then
              hlgroup = 'OrgAgendaScheduleFuture'
            end
          elseif date_label == 'Today' and is_same_day then
            date_label = ''
          end
          local line = string.format(
            '%s %s: %s %s %s',
            category,
            date_label,
            item.headline.todo_keyword.value,
            item.headline.title,
            tags
          )
          if hlgroup then
            highlights = {{
              line = #content,
              hlgroup = hlgroup,
              from = 0,
              to = -1
            }}
          end
          if item.headline.todo_keyword.range then
            local col_start = #string.format('%s %s: ', category, date_label)
            local col_end = col_start + #item.headline.todo_keyword.value
            table.insert(highlights, {
              line = #content,
              hlgroup = keyword_hl_map[item.headline.todo_keyword.value],
              from = col_start,
              to = col_end
            })
          end
          table.insert(content, {
            value = line,
            id = item.headline.id,
            file = filename,
            line = item.headline.range.from.line,
            highlights = highlights
          })
        end
      end
    end
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
  vim.api.nvim_buf_set_lines(0, 0, -1, true, vim.tbl_map(function(item) return item.value end, content))
  vim.bo.modifiable = false
  vim.bo.modified = false
  for _, item in ipairs(content) do
    if item.highlights and #item.highlights > 0 then
      utils.highlight(item.highlights)
    end
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
  vim.cmd('edit '..item.file)
  vim.fn.cursor(item.line, 0)
end

function Agenda:get_headlines_for_today(orgfile, today)
  local headlines = {}
  for _, item in pairs(orgfile:get_items()) do
    local dates = {}
    if item.type == Types.HEADLINE and not item:is_done() and not item:is_archived() then
      for _, date in ipairs(item.dates) do
        local warning_date = date:get_warning_date()
        if date:is_deadline() and warning_date:is_same_or_before(today) then
          table.insert(dates, date)
        elseif warning_date:is_same(today, 'day') then
          table.insert(dates, date)
        end
      end
    end
    if #dates > 0 then
      table.insert(headlines, { headline = item, dates = dates })
    end
  end

  return headlines
end

function Agenda:get_headlines_for_date(orgfile, date)
  local headlines = {}
  for _, item in pairs(orgfile:get_items()) do
    local dates = {}
    if item.type == Types.HEADLINE and not item:is_done() and not item:is_archived() then
      for _, d in ipairs(item.dates) do
        if d:is_same(date, 'day') then
          table.insert(dates, d)
        end
      end
    end
    if #dates > 0 then
      table.insert(headlines, { headline = item, dates = dates })
    end
  end

  return headlines
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

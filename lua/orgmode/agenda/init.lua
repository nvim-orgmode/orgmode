local Date = require('orgmode.objects.date')
local Types = require('orgmode.parser.types')
local Agenda = {}

-- TODO: Move to utils and add test
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

function Agenda:new(opts)
  opts = opts or {}
  local data = {
    files = opts.files or {},
    span = 'week',
    day_format = '%A %d %B %Y',
    from = Date.now(),
    to = Date.now():add({ day = 7 }),
    content = {}
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Agenda:render()
  local dates = self.from:get_range_until(self.to)
  local content = {{ value = 'Span: '..self.span }}
  for _, date in ipairs(dates) do
    local date_string = date:format(self.day_format)
    local is_today = date:is_today()
    if is_today then
      date_string = date_string..' [Today]'
    end
    table.insert(content, { value = date_string })
    for filename, orgfile in pairs(self.files) do
      local headlines = {}
      if is_today then
        headlines = self:get_headlines_for_today(orgfile, date)
      else
        headlines = self:get_headlines_for_date(orgfile, date)
      end
      for _, item in ipairs(headlines) do
        local sorted_dates = sort_dates(item.dates)
        local tags = ''
        if #item.headline.tags > 0 then
          tags = ':'..table.concat(item.headline.tags, ':')..':'
        end

        for _, d in ipairs(sorted_dates) do
          local date_label = d:humanize(date)
          local is_same_day = d:is_same(date, 'day')
          if d:is_deadline() and is_same_day then
            date_label = 'Deadline'
            if not d.date_only and is_today then
              date_label = d:format('%H:%M')..'...Deadline'
            end
          elseif d:is_scheduled() and is_same_day then
            date_label = 'Scheduled'
          elseif date_label == 'Today' and is_same_day then
            date_label = ''
          end
          local line = string.format(
          '  %s: %s: %s %s %s',
          item.headline.category,
          date_label,
          item.headline.todo_keyword,
          item.headline.title,
          tags
          )
          table.insert(content, {
            value = line,
            id = item.headline.id,
            file = filename,
            line = item.headline.range.from.line,
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
end

function Agenda:open()
  self:render()
  vim.fn.search(self.from:format(self.day_format))
end

function Agenda:reset()
  self.from = Date.now()
  self.to = self.from:add({ [self.span] = 1 })
  self:render()
  vim.fn.search(self.from:format(self.day_format))
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
  local now = Date:now()
  self.span = span
  self.from = now:start_of(self.span)
  self.to = now:end_of(self.span)
  self:render()
  vim.fn.search(now:format(self.day_format))
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


return Agenda

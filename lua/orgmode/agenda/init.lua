local Date = require('orgmode.objects.date')
local Types = require('orgmode.parser.types')
local Agenda = {}

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
    files = opts.files or {}
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Agenda:open()
  local dates = Date.now():end_of('day'):get_range_until(Date.now():add({ day = 7 }))
  local content = { 'Span: week' }
  for _, date in ipairs(dates) do
    local date_string = date:format('%A %d %B %Y')
    local is_today = date:is_today()
    if is_today then
      date_string = date_string..' [Today]'
    end
    table.insert(content, date_string)
    for _, orgfile in pairs(self.files) do
      local headlines = {}
      if is_today then
        headlines = self:get_headlines_for_today(orgfile, date)
      else
        headlines = self:get_headlines_for_date(orgfile, date)
      end
      for _, item in ipairs(headlines) do
        local sorted_dates = sort_dates(item.dates)
        local tags = ''
        if not item.headline.tags then
          print(vim.inspect(item))
        end
        if #item.headline.tags > 0 then
          tags = ':'..table.concat(item.headline.tags, ':')..':'
        end

        for _, d in ipairs(sorted_dates) do
          local date_label = d:humanize(date)
          -- TODO: Improve dates
          if d:is_deadline() then
            date_label = 'Deadline'
          elseif d:is_scheduled() then
            date_label = 'Scheduled'
          elseif date_label == 'Today' then
            date_label = ''
          end
          local line = string.format(
            '  %s: %s: %s %s %s',
            orgfile:get_category(item.headline),
            date_label,
            item.headline.todo_keyword,
            item.headline.title,
            tags
          )
          table.insert(content, line)
        end
      end
    end
  end

  vim.cmd('pedit '..vim.fn.tempname())
  vim.cmd[[wincmd p]]
  vim.bo.modifiable = true
  vim.api.nvim_buf_set_lines(0, 0, -1, true, content)
  vim.bo.modified = false
  vim.bo.modifiable = false
end

function Agenda:get_headlines_for_today(orgfile, today)
  local headlines = {}
  for _, item in pairs(orgfile:get_items()) do
    local dates = {}
    if item.type == Types.HEADLINE and not item:is_done() then
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
    if item.type == Types.HEADLINE and not item:is_done() then
      for _, d in ipairs(item.dates) do
        if d:is_same(date, 'day') then
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


return Agenda

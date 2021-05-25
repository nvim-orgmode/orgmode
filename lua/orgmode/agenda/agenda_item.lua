local AgendaHighlights = require('orgmode.agenda.highlights')
local hl_map = AgendaHighlights.get_agenda_hl_map()
local padding = '...... '
-- TODO: Check if there is a configuration for this
local FUTURE_DEADLINE_AS_WARNING_DAYS = 7

---@class AgendaItem
---@field date Date
---@field headline_date Date
---@field headline Headline
---@field is_valid boolean
---@field is_today boolean
---@field is_same_day boolean
---@field label string
---@field highlights table[]
local AgendaItem = {}


---@param headline_date Date single date in a headline
---@param headline Headline
---@param date Date date for which item should be rendered
function AgendaItem:new(headline_date, headline, date)
  local opts = {}
  opts.headline_date = headline_date
  opts.headline = headline
  opts.date = date
  opts.is_valid = false
  opts.is_today = date:is_today()
  opts.is_same_day = headline_date:is_same(date, 'day') or headline_date:repeats_on(date)
  opts.label = ''
  opts.highlights = {}
  setmetatable(opts, self)
  self.__index = self
  opts:_process()
  return opts
end

function AgendaItem:_process()
  if self.is_today then
    self.is_valid = self:_is_valid_for_today()
  else
    self.is_valid = self:_is_valid_for_date()
  end

  if self.is_valid then
    self.label = self:_generate_label()
    local highlight = self:_generate_highlight()
    if highlight then
      table.insert(self.highlights, highlight)
    end
    self:_add_keyword_highlight()
  end
end

function AgendaItem:_is_valid_for_today()
  if not self.headline_date.active or self.headline_date:is_closed() then return false end
  if self.headline_date:is_none() then
    return self.is_same_day
  end

  if self.headline_date:is_deadline() then
    if self.is_same_day then return true end
    if self.headline_date:is_before(self.date, 'day') then
      return not self.headline:is_done()
    end
    return not self.headline:is_done() and self.date:is_between(self.headline_date:get_adjusted_date(), self.headline_date, 'day')
  end

  if not self.headline_date:get_negative_adjustment() then
    if self.is_same_day then return true end
    if self.headline_date:is_before(self.date, 'day') and not self.headline:is_done() then return true end
    return false
  end

  if self.headline_date:get_adjusted_date():is_same_or_before(self.date, 'day') and not self.headline:is_done() then
    return true
  end

  return false
end

function AgendaItem:_is_valid_for_date()
  if not self.headline_date.active or self.headline_date:is_closed() then return false end

  if not self.headline_date:is_scheduled() or not self.headline_date:get_negative_adjustment() then
    return self.is_same_day
  end

  return false
end

function AgendaItem:_generate_label()
  local time = not self.headline_date.date_only and self.headline_date:format('%H:%M')..padding or ''
  if self.headline_date:is_deadline() then
    if self.is_same_day then
      return time..'Deadline:'
    end
    return self.headline_date:humanize(self.date)..':'
  end

  if self.headline_date:is_scheduled() then
    if self.is_same_day then
      return time..'Scheduled:'
    end

    local diff = math.abs(self.date:diff(self.headline_date))

    return 'Sched. '..diff..'x:'
  end

  return time
end

function AgendaItem:_generate_highlight()
  if self.headline_date:is_deadline() then
    if self.headline:is_done() then
      return { hlgroup = hl_map.scheduled }
    end
    if self.is_today and self.headline_date:is_after(self.date, 'day') then
      local diff = math.abs(self.date:diff(self.headline_date))
      if diff <= FUTURE_DEADLINE_AS_WARNING_DAYS then
        return { hlgroup = hl_map.scheduledPast }
      end
      return nil
    end

    return { hlgroup = hl_map.deadline }
  end

  if self.headline_date:is_scheduled() then
    if self.headline_date:is_past('day') then
      return { hlgroup = hl_map.scheduledPast }
    end

    return { hlgroup = hl_map.scheduled }
  end

  return nil
end

function AgendaItem:_add_keyword_highlight()
  if self.headline.todo_keyword.value == '' then return end
  local hlgroup = hl_map[self.headline.todo_keyword.value]
  if hlgroup then
    table.insert(self.highlights, {
      hlgroup = hlgroup,
      todo_keyword = self.headline.todo_keyword.value
    })
  end
end

return AgendaItem

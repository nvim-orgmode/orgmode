local Highlights = require('orgmode.colors.highlights')
local hl_map = Highlights.get_agenda_hl_map()
local config = require('orgmode.config')
local FUTURE_DEADLINE_AS_WARNING_DAYS = math.floor(config.org_deadline_warning_days / 2)
local function add_padding(datetime)
  if datetime:len() >= 11 then return datetime..' ' end
  return datetime..string.rep('.', 11 - datetime:len())..' '
end

---@class AgendaItem
---@field date Date
---@field headline_date Date
---@field headline Headline
---@field is_valid boolean
---@field is_today boolean
---@field is_same_day boolean
---@field is_in_date_range boolean
---@field date_range_days number
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
  opts.is_in_date_range = headline_date:is_none() and headline_date:is_in_date_range(date)
  opts.date_range_days = headline_date:get_date_range_days()
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
  if not self.headline_date.active or self.headline_date:is_closed() or self.headline_date:is_obsolete_range_end() then return false end
  if self.headline_date:is_none() then
    return self.is_same_day or self.is_in_date_range
  end

  if self.headline_date:is_deadline() then
    if self.headline:is_done() and config.org_agenda_skip_deadline_if_done then return false end
    if self.is_same_day then return true end
    if self.headline_date:is_before(self.date, 'day') then
      return not self.headline:is_done()
    end
    return not self.headline:is_done() and self.date:is_between(self.headline_date:get_adjusted_date(), self.headline_date, 'day')
  end

  if self.headline:is_done() and config.org_agenda_skip_scheduled_if_done then return false end

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
  if not self.headline_date.active or self.headline_date:is_closed() or self.headline_date:is_obsolete_range_end() then return false end

  if self.headline:is_done() then
    if self.headline_date:is_deadline() and config.org_agenda_skip_deadline_if_done then
      return false
    end
    if self.headline_date:is_scheduled() and config.org_agenda_skip_scheduled_if_done then
      return false
    end
  end

  if not self.headline_date:is_scheduled() or not self.headline_date:get_negative_adjustment() then
    return self.is_same_day or self.is_in_date_range
  end

  return false
end

function AgendaItem:_generate_label()
  local time = not self.headline_date.date_only and add_padding(self.headline_date:format_time()) or ''
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

  if self.headline_date.is_date_range_start then
    if not self.is_in_date_range then return time end
    local range = string.format('(%d/%d):', self.date:diff(self.headline_date) + 1, self.date_range_days)
    if not self.is_same_day then
      return range
    end
    return time..range
  end

  if self.headline_date.is_date_range_end then
    local range = string.format('(%d/%d):', self.date_range_days, self.date_range_days)
    return time..range
  end

  return time
end

function AgendaItem:_generate_highlight()
  if self.headline_date:is_deadline() then
    if self.headline:is_done() then
      return { hlgroup = hl_map.ok }
    end
    if self.is_today and self.headline_date:is_after(self.date, 'day') then
      local diff = math.abs(self.date:diff(self.headline_date))
      if diff <= FUTURE_DEADLINE_AS_WARNING_DAYS then
        return { hlgroup = hl_map.warning }
      end
      return nil
    end

    return { hlgroup = hl_map.deadline }
  end

  if self.headline_date:is_scheduled() then
    if self.headline_date:is_past('day') and not self.headline:is_done() then
      return { hlgroup = hl_map.warning }
    end

    return { hlgroup = hl_map.ok }
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

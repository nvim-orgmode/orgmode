---@diagnostic disable: inject-field
local Date = require('orgmode.objects.date')
local config = require('orgmode.config')
local utils = require('orgmode.utils')
local Search = require('orgmode.files.elements.search')
local OrgAgendaTodosType = require('orgmode.agenda.types.todo')
local Input = require('orgmode.ui.input')

---@alias OrgAgendaTodoIgnoreDeadlinesTypes 'all' | 'near' | 'far' | 'past' | 'future'
---@alias OrgAgendaTodoIgnoreScheduledTypes 'all' | 'past' | 'future'

---@class OrgAgendaTagsTypeOpts:OrgAgendaTodosTypeOpts
---@field match_query? string
---@field todo_ignore_deadlines OrgAgendaTodoIgnoreDeadlinesTypes
---@field todo_ignore_scheduled OrgAgendaTodoIgnoreScheduledTypes

---@class OrgAgendaTagsType:OrgAgendaTodosType
---@field match_query string
---@field todo_ignore_deadlines OrgAgendaTodoIgnoreDeadlinesTypes
---@field todo_ignore_scheduled OrgAgendaTodoIgnoreScheduledTypes
local OrgAgendaTagsType = {}
OrgAgendaTagsType.__index = OrgAgendaTagsType

---@param opts OrgAgendaTagsTypeOpts
function OrgAgendaTagsType:new(opts)
  opts.todo_only = opts.todo_only or false
  opts.sorting_strategy = opts.sorting_strategy or vim.tbl_get(config.org_agenda_sorting_strategy, 'tags') or {}
  if not opts.id then
    opts.subheader = 'Press "r" to update search'
  end
  setmetatable(self, { __index = OrgAgendaTodosType })
  local obj = OrgAgendaTodosType:new(opts)
  setmetatable(obj, self)
  obj.match_query = opts.match_query or ''
  obj.todo_ignore_deadlines = opts.todo_ignore_deadlines
  obj.todo_ignore_scheduled = opts.todo_ignore_scheduled
  return obj
end

function OrgAgendaTagsType:_get_header()
  if self.header then
    return self.header
  end

  return 'Headlines with TAGS match: ' .. (self.match_query or '')
end

function OrgAgendaTagsType:prepare()
  if self.id or self.match_query and self.match_query ~= '' then
    return self
  end

  return self:get_tags()
end

function OrgAgendaTagsType:get_file_headlines(file)
  local headlines = file:apply_search(Search:new(self.match_query), self.todo_only)
  if self.todo_ignore_deadlines then
    headlines = vim.tbl_filter(function(headline) ---@cast headline OrgHeadline
      local deadline_date = headline:get_deadline_date()
      if not deadline_date then
        return true
      end
      if self.todo_ignore_deadlines == 'all' then
        return false
      end
      if self.todo_ignore_deadlines == 'near' then
        local diff = deadline_date:diff(Date.now(), 'day')
        return diff > config.org_deadline_warning_days
      end
      if self.todo_ignore_deadlines == 'far' then
        local diff = deadline_date:diff(Date.now(), 'day')
        return diff <= config.org_deadline_warning_days
      end
      if self.todo_ignore_deadlines == 'past' then
        return not deadline_date:is_same_or_before(Date.today(), 'day')
      end
      if self.todo_ignore_deadlines == 'future' then
        return not deadline_date:is_after(Date.today(), 'day')
      end
      return true
    end, headlines)
  end
  if self.todo_ignore_scheduled then
    headlines = vim.tbl_filter(function(headline) ---@cast headline OrgHeadline
      local scheduled_date = headline:get_scheduled_date()
      if not scheduled_date then
        return true
      end
      if self.todo_ignore_scheduled == 'all' then
        return false
      end
      if self.todo_ignore_scheduled == 'past' then
        return scheduled_date:is_same_or_before(Date.today(), 'day')
      end
      if self.todo_ignore_scheduled == 'future' then
        return scheduled_date:is_after(Date.today(), 'day')
      end
      return true
    end, headlines)
  end
  return headlines
end

function OrgAgendaTagsType:get_tags()
  return Input.open('Match: ', self.match_query or '', function(arg_lead)
    return utils.prompt_autocomplete(arg_lead, self.files:get_tags())
  end):next(function(tags)
    if not tags then
      return false
    end
    if vim.trim(tags) == '' then
      utils.echo_warning('Invalid tag.')
      return false
    end
    self.match_query = tags
    return self
  end)
end

function OrgAgendaTagsType:redraw()
  -- Skip prompt for custom views
  if self.id then
    return self
  end
  return self:get_tags()
end

return OrgAgendaTagsType

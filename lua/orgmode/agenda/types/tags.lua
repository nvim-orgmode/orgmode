---@diagnostic disable: inject-field
local Date = require('orgmode.objects.date')
local config = require('orgmode.config')
local utils = require('orgmode.utils')
local validator = require('orgmode.utils.validator')
local Search = require('orgmode.files.elements.search')
local OrgAgendaTodosType = require('orgmode.agenda.types.todo')

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
  local match_query = opts.match_query
  if not opts.id and (not match_query or match_query == '') then
    match_query = self:get_tags(opts.files)
    if not match_query then
      return nil
    end
  end

  setmetatable(self, { __index = OrgAgendaTodosType })
  local obj = OrgAgendaTodosType:new(opts)
  setmetatable(obj, self)
  obj.match_query = match_query or ''
  obj.todo_ignore_deadlines = opts.todo_ignore_deadlines
  obj.todo_ignore_scheduled = opts.todo_ignore_scheduled
  obj.header = opts.header or ('Headlines with TAGS match: ' .. obj.match_query)
  return obj
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
        local diff = deadline_date:diff(Date.now())
        return diff > config.org_deadline_warning_days
      end
      if self.todo_ignore_deadlines == 'far' then
        local diff = deadline_date:diff(Date.now())
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

---@param files? OrgFiles
function OrgAgendaTagsType:get_tags(files)
  local tags = utils.input('Match: ', self.match_query or '', function(arg_lead)
    return utils.prompt_autocomplete(arg_lead, (files or self.files):get_tags())
  end)
  if vim.trim(tags) == '' then
    return utils.echo_warning('Invalid tag.')
  end
  return tags
end

function OrgAgendaTagsType:redraw()
  -- Skip prompt for custom views
  if self.id then
    return self
  end
  self.match_query = self:get_tags() or ''
  self.header = 'Headlines with TAGS match: ' .. self.match_query
  return self
end

return OrgAgendaTagsType

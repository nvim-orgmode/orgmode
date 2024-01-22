local Date = require('orgmode.objects.date')
local orgmode = require('orgmode')

---@class OrgAgenda
local OrgAgenda = {}

---@alias OrgAgendaFilter string see Filters to apply to the current view. See `:help orgmode-org_agenda_filter` for more information

local function get_date(date, name)
  if not date then
    return nil
  end
  if type(date) == Date then
    return date
  end
  if type(date) == 'string' then
    return Date.from_string(date)
  end

  error(('Invalid format for "%s" date in Org Agenda'):format(name))
end

---@return table
local function org_instance()
  local org = orgmode.instance()
  if not org then
    error('Orgmode was not set up. Run require("orgmode").setup() first.')
  end
  org:init()
  return org
end

---@class OrgAgendaOptions
---@field filters? OrgAgendaFilter
---@field from? string | OrgDate
---@field span? number | 'day' | 'week' | 'month' | 'year'

---@param options? OrgAgendaOptions
function OrgAgenda.agenda(options)
  options = options or {}
  local org = org_instance()
  if options.filters and options.filters ~= '' then
    org.agenda.filters:parse(options.filters, true)
  end
  local from = get_date(options.from, 'from')
  org.agenda:agenda({
    from = from,
    span = options.span,
  })
end

---@class OrgAgendaTodosOptions
---@field filters? OrgAgendaFilter

---@param options? OrgAgendaTodosOptions
function OrgAgenda.todos(options)
  options = options or {}
  local org = org_instance()
  if options.filters and options.filters ~= '' then
    org.agenda.filters:parse(options.filters, true)
  end
  org.agenda:todos()
end

---@class OrgAgendaTagsOptions
---@field filters? OrgAgendaFilter
---@field todo_only? boolean

---@param options? OrgAgendaTagsOptions
function OrgAgenda.tags(options)
  options = options or {}
  local org = org_instance()
  if options.filters and options.filters ~= '' then
    org.agenda.filters:parse(options.filters, true)
  end
  org.agenda:tags({
    todo_only = options.todo_only,
  })
end

return OrgAgenda

local Date = require('orgmode.objects.date')
local orgmode = require('orgmode')

---@class OrgApiAgenda
local OrgAgenda = {}

---@alias OrgApiAgendaFilter string see Filters to apply to the current view. See `:help orgmode-org_agenda_filter` for more information

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

---@class OrgApiAgendaOptions
---@field filters? OrgApiAgendaFilter
---@field from? string | OrgDate
---@field span? number | 'day' | 'week' | 'month' | 'year'

---@param options? OrgApiAgendaOptions
function OrgAgenda.agenda(options)
  options = options or {}
  if options.filters and options.filters ~= '' then
    orgmode.agenda.filters:parse(options.filters, true)
  end
  local from = get_date(options.from, 'from')
  orgmode.agenda:agenda({
    from = from,
    span = options.span,
  })
end

---@class OrgAgendaTodosOptions
---@field filters? OrgApiAgendaFilter

---@param options? OrgAgendaTodosOptions
function OrgAgenda.todos(options)
  options = options or {}
  if options.filters and options.filters ~= '' then
    orgmode.agenda.filters:parse(options.filters, true)
  end
  orgmode.agenda:todos()
end

---@class OrgAgendaTagsOptions
---@field filters? OrgApiAgendaFilter
---@field todo_only? boolean

---@param options? OrgAgendaTagsOptions
function OrgAgenda.tags(options)
  options = options or {}
  if options.filters and options.filters ~= '' then
    orgmode.agenda.filters:parse(options.filters, true)
  end
  orgmode.agenda:tags({
    todo_only = options.todo_only,
  })
end

return OrgAgenda

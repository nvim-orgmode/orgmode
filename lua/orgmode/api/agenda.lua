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

local function get_opts(options)
  options = options or {}
  local opts = {}
  if options.filters and options.filters ~= '' then
    opts.filter = options.filters
  end
  opts.header = options.header
  return opts
end

---@class OrgApiAgendaOptions
---@field filters? OrgApiAgendaFilter
---@field from? string | OrgDate
---@field span? OrgAgendaSpan
---@field header? string

---@param options? OrgApiAgendaOptions
function OrgAgenda.agenda(options)
  options = options or {}
  local opts = get_opts(options)
  opts.from = get_date(options.from, 'from')
  opts.span = options.span
  opts.header = options.header
  orgmode.agenda:agenda(opts)
end

---@class OrgApiAgendaTodosOptions
---@field filters? OrgApiAgendaFilter
---@field header? string

---@param options? OrgApiAgendaTodosOptions
function OrgAgenda.todos(options)
  options = options or {}
  local opts = get_opts(options)
  orgmode.agenda:todos(opts)
end

---@class OrgApiAgendaTagsOptions
---@field filters? OrgApiAgendaFilter Agenda filters for tags and categories
---@field match_query? string Match query to find the todos
---@field todo_only? boolean
---@field header? string

---@param options? OrgApiAgendaTagsOptions
function OrgAgenda.tags(options)
  options = options or {}
  local opts = get_opts(options)
  opts.todo_only = options.todo_only
  opts.match_query = options.match_query
  orgmode.agenda:tags(opts)
end

---@class OrgApiAgendaTagsTodoOptions
---@field filters? OrgApiAgendaFilter Agenda filters for tags and categories
---@field match_query? string Match query to find the todos
---@field header? string

---@param options? OrgApiAgendaTagsOptions
function OrgAgenda.tags_todo(options)
  options = options or {}
  local opts = get_opts(options)
  opts.match_query = options.match_query
  orgmode.agenda:tags_todo(opts)
end

return OrgAgenda

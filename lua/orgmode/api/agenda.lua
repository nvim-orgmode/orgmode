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

  error(('Invalid format for "%s" date in Org Agenda'):format(name), 0)
end

local function get_shared_opts(options)
  options = options or {}
  local opts = {}
  if options.filters and options.filters ~= '' then
    opts.filter = options.filters
  end
  opts.header = options.header
  opts.agenda_files = options.org_agenda_files
  opts.sorting_strategy = options.org_agenda_sorting_strategy
  opts.tag_filter = options.org_agenda_tag_filter_preset
  opts.category_filter = options.org_agenda_category_filter_preset
  opts.remove_tags = options.org_agenda_remove_tags
  return opts
end

local function get_tags_opts(options)
  local opts = get_shared_opts(options)
  opts.match_query = options.match_query
  opts.todo_ignore_scheduled = options.org_agenda_todo_ignore_scheduled
  opts.todo_ignore_deadlines = options.org_agenda_todo_ignore_deadlines
  return opts
end

---@class OrgApiAgendaOpts
---@field filters? OrgApiAgendaFilter
---@field header? string
---@field org_agenda_files? string[]
---@field org_agenda_tag_filter_preset? string
---@field org_agenda_category_filter_preset? string
---@field org_agenda_sorting_strategy? OrgAgendaSortingStrategy[]
---@field org_agenda_remove_tags? boolean

---@class OrgApiAgendaOptions:OrgApiAgendaOpts
---@field from? string | OrgDate
---@field span? OrgAgendaSpan

---@param options? OrgApiAgendaOptions
function OrgAgenda.agenda(options)
  options = options or {}
  local opts = get_shared_opts(options)
  opts.from = get_date(options.from, 'from')
  opts.span = options.span
  orgmode.agenda:agenda(opts)
end

---@class OrgApiAgendaTodosOptions:OrgApiAgendaOpts

---@param options? OrgApiAgendaTodosOptions
function OrgAgenda.todos(options)
  options = options or {}
  local opts = get_shared_opts(options)
  orgmode.agenda:todos(opts)
end

---@class OrgApiAgendaTagsTodoOptions:OrgApiAgendaOpts
---@field match_query? string Match query to find the todos
---@field org_agenda_todo_ignore_scheduled? OrgAgendaTodoIgnoreScheduledTypes
---@field org_agenda_todo_ignore_deadlines? OrgAgendaTodoIgnoreDeadlinesTypes

---@param options? OrgApiAgendaTagsOptions
function OrgAgenda.tags_todo(options)
  options = options or {}
  local opts = get_tags_opts(options)
  orgmode.agenda:tags_todo(opts)
end

---@class OrgApiAgendaTagsOptions:OrgApiAgendaTagsTodoOptions
---@field todo_only? boolean

---@param options? OrgApiAgendaTagsOptions
function OrgAgenda.tags(options)
  options = options or {}
  local opts = get_tags_opts(options)
  opts.todo_only = options.todo_only
  orgmode.agenda:tags(opts)
end

---@param key string Key in the agenda prompt (for example: "a", "t", "m", "M")
function OrgAgenda.open_by_key(key)
  return orgmode.agenda:open_by_key(key)
end

---Get the headline at the cursor position in the agenda view
---@return OrgApiHeadline | nil
function OrgAgenda.get_headline_at_cursor()
  local headline = orgmode.agenda:get_headline_at_cursor()

  if headline then
    local file = require('orgmode.api').load(headline.file.filename)
    return file:get_headline_on_line(headline:get_range().start_line)
  end
end

return OrgAgenda

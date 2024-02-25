local AgendaFilter = require('orgmode.agenda.filter')
local AgendaTodosView = require('orgmode.agenda.views.todos')
local Search = require('orgmode.files.elements.search')
local Range = require('orgmode.files.elements.range')
local utils = require('orgmode.utils')

---@class OrgAgendaTagsView
---@field items table[]
---@field content table[]
---@field highlights table[]
---@field header string
---@field search string
---@field filters OrgAgendaFilter
---@field todo_only boolean
---@field files OrgFiles
local AgendaTagsView = {}

function AgendaTagsView:new(opts)
  opts = opts or {}
  local data = {
    content = {},
    highlights = {},
    items = {},
    search = opts.search or '',
    todo_only = opts.todo_only or false,
    filters = opts.filters or AgendaFilter:new(),
    header = opts.org_agenda_overriding_header,
    files = opts.files,
  }

  setmetatable(data, self)
  self.__index = self
  return data
end

function AgendaTagsView:build()
  local tags = vim.fn.OrgmodeInput('Match: ', self.search, function(arg_lead)
    utils.prompt_autocomplete(arg_lead, self.files:get_tags())
  end)
  if vim.trim(tags) == '' then
    return utils.echo_warning('Invalid tag.')
  end
  local search = Search:new(tags)
  self.items = {}
  for _, orgfile in ipairs(self.files:all()) do
    local headlines_filtered = orgfile:apply_search(search, self.todo_only)
    for _, headline in ipairs(headlines_filtered) do
      if self.filters:matches(headline) then
        table.insert(self.items, headline)
      end
    end
  end

  self.search = tags
  self.content = {
    { line_content = 'Headlines with TAGS match: ' .. tags },
    { line_content = 'Press "r" to update search' },
  }
  self.highlights = {
    { hlgroup = 'Comment', range = Range.for_line_hl(1) },
    { hlgroup = 'Comment', range = Range.for_line_hl(2) },
  }

  self.active_view = self.todo_only and 'tags_todo' or 'tags'
  AgendaTodosView.generate_view(self.items, self.content, self.filters)

  return self
end

return AgendaTagsView

local AgendaFilter = require('orgmode.agenda.filter')
local AgendaTodosView = require('orgmode.agenda.views.todos')
local Search = require('orgmode.parser.search')
local Files = require('orgmode.parser.files')
local Range = require('orgmode.parser.range')
local utils = require('orgmode.utils')

---@class AgendaTagsView
---@field items table[]
---@field content table[]
---@field highlights table[]
---@field header string
---@field search string
---@field filters AgendaFilter
---@field todo_only boolean
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
  }

  setmetatable(data, self)
  self.__index = self
  return data
end

function AgendaTagsView:build()
  local tags = vim.fn.OrgmodeInput('Match: ', self.search, Files.autocomplete_tags)
  if vim.trim(tags) == '' then
    return utils.echo_warning('Invalid tag.')
  end
  local search = Search:new(tags)
  self.items = {}
  for _, orgfile in ipairs(Files.all()) do
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

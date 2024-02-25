local AgendaFilter = require('orgmode.agenda.filter')
local AgendaTodosView = require('orgmode.agenda.views.todos')
local Range = require('orgmode.files.elements.range')
local utils = require('orgmode.utils')

---@class OrgAgendaSearchView
---@field items OrgHeadline[]
---@field content table[]
---@field highlights table[]
---@field header string
---@field search string
---@field filters OrgAgendaFilter
---@field files OrgFiles
local AgendaSearchView = {}

function AgendaSearchView:new(opts)
  opts = opts or {}
  local data = {
    content = {},
    highlights = {},
    items = {},
    search = opts.search or '',
    filters = opts.filters or AgendaFilter:new(),
    header = opts.org_agenda_overriding_header,
    files = opts.files,
  }

  setmetatable(data, self)
  self.__index = self
  return data
end

function AgendaSearchView:build()
  local search_term = self.search
  if not self.filters.applying then
    search_term = vim.fn.OrgmodeInput('Enter search term: ', self.search)
  end
  self.search = search_term
  self.items = self.files:find_headlines_matching_search_term(search_term, false, true)
  if self.filters:should_filter() then
    self.items = vim.tbl_filter(function(item)
      return self.filters:matches(item)
    end, self.items)
  end

  self.content = {
    { line_content = 'Search words: ' .. search_term },
    { line_content = 'Press "r" to update search' },
  }
  self.highlights = {
    { hlgroup = 'Comment', range = Range.for_line_hl(1) },
    { hlgroup = 'Comment', range = Range.for_line_hl(2) },
  }

  self.active_view = 'search'
  AgendaTodosView.generate_view(self.items, self.content, self.filters)
  return self
end

return AgendaSearchView

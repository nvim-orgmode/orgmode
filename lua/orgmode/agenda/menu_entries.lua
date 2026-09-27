local config = require('orgmode.config')
local utils = require('orgmode.utils')

---@class OrgAgendaMenuEntry
---@field key string
---@field label string
---@field method? string Agenda method that opens a built-in view
---@field command? OrgAgendaCustomCommand

local MenuEntries = {}

---@type OrgAgendaMenuEntry[]
MenuEntries.builtin = {
  { key = 'a', label = 'Agenda for current week or day', method = 'agenda' },
  { key = 't', label = 'List of all TODO entries', method = 'todos' },
  { key = 'm', label = 'Match a TAGS/PROP/TODO query', method = 'tags' },
  { key = 'M', label = 'Like m, but only TODO entries', method = 'tags_todo' },
  { key = 's', label = 'Search for keywords', method = 'search' },
}

---@return OrgAgendaMenuEntry[]
function MenuEntries.custom_commands()
  local entries = {}
  for key, command in utils.sorted_pairs(config.org_agenda_custom_commands or {}) do
    table.insert(entries, { key = key, label = command.description or '', command = command })
  end
  return entries
end

return MenuEntries

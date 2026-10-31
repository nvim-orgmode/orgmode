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

---@param command OrgAgendaCustomCommand
---@return string
local function custom_command_label(command)
  if command.description then
    return command.description
  end
  return table.concat(
    vim.tbl_map(function(block)
      return block.type
    end, command.types or {}),
    ' + '
  )
end

---@return OrgAgendaMenuEntry[]
function MenuEntries.custom_commands()
  local entries = {}
  for key, command in utils.sorted_pairs(config.org_agenda_custom_commands or {}) do
    table.insert(entries, { key = key, label = custom_command_label(command), command = command })
  end
  return entries
end

--- Built-in views and custom commands in menu order, each opening its view
---@return OrgMenuKeymap[]
function MenuEntries.keymaps()
  local keymaps = {}
  local entries = vim.list_extend(vim.list_extend({}, MenuEntries.builtin), MenuEntries.custom_commands())
  for _, entry in ipairs(entries) do
    table.insert(keymaps, {
      key = entry.key,
      desc = entry.label,
      action = function()
        return require('orgmode').agenda:open_by_key(entry.key)
      end,
    })
  end
  return keymaps
end

return MenuEntries

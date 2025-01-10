---@alias OrgAgendaTypes 'agenda' | 'todo' | 'tags' | 'tags_todo' | 'search'
return {
  agenda = require('orgmode.agenda.types.agenda'),
  todo = require('orgmode.agenda.types.todo'),
  tags = require('orgmode.agenda.types.tags'),
  tags_todo = require('orgmode.agenda.types.tags_todo'),
  search = require('orgmode.agenda.types.search'),
}

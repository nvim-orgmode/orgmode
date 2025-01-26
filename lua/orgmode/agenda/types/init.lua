---@class OrgAgendaViewType
---@field render fun(self: OrgAgendaViewType, bufnr:number, current_line?: number): OrgAgendaView
---@field get_lines fun(self: OrgAgendaViewType): OrgAgendaLine | OrgAgendaLine[]
---@field get_line fun(self: OrgAgendaViewType, line_nr: number): OrgAgendaLine | nil
---@field rerender_agenda_line fun(self: OrgAgendaViewType, agenda_line: OrgAgendaLine, headline: OrgHeadline): OrgAgendaLine | nil
---@field view OrgAgendaView
---@field prepare fun(self: OrgAgendaViewType): OrgPromise<OrgAgendaViewType>
---@field redraw? fun(self: OrgAgendaViewType): OrgPromise<OrgAgendaViewType>
---@field redo? fun(self: OrgAgendaViewType): OrgPromise<OrgAgendaViewType>

---@alias OrgAgendaTypes 'agenda' | 'todo' | 'tags' | 'tags_todo' | 'search'
return {
  agenda = require('orgmode.agenda.types.agenda'),
  todo = require('orgmode.agenda.types.todo'),
  tags = require('orgmode.agenda.types.tags'),
  tags_todo = require('orgmode.agenda.types.tags_todo'),
  search = require('orgmode.agenda.types.search'),
}

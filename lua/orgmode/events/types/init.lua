---@class OrgEvent
---@field type string

return {
  TodoChanged = require('orgmode.events.types.todo_changed_event'),
  HeadlinePromoted = require('orgmode.events.types.headline_promoted_event'),
  HeadlineDemoted = require('orgmode.events.types.headline_demoted_event'),
  HeadingToggled = require('orgmode.events.types.heading_toggled'),
  NoteAdded = require('orgmode.events.types.note_added_event'),
  ClockedIn = require('orgmode.events.types.clocked_in'),
  ClockedOut = require('orgmode.events.types.clocked_out'),
  AttachChanged = require('orgmode.events.types.attach_changed_event'),
  AttachOpened = require('orgmode.events.types.attach_opened_event'),
  HeadlineArchived = require('orgmode.events.types.headline_archived_event'),
}

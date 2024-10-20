---@class OrgEvent
---@field type string

return {
  TodoChanged = require('orgmode.events.types.todo_changed_event'),
  HeadlinePromoted = require('orgmode.events.types.headline_promoted_event'),
  HeadlineDemoted = require('orgmode.events.types.headline_demoted_event'),
}

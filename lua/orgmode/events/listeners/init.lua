local Events = require('orgmode.events.types')
local AlignTags = require('orgmode.events.listeners.align_tags')
local AttachMaybeDeleteArchived = require('orgmode.events.listeners.attach_maybe_delete_archived')

return {
  [Events.TodoChanged] = {
    AlignTags,
  },
  [Events.HeadlineDemoted] = {
    AlignTags,
  },
  [Events.HeadlinePromoted] = {
    AlignTags,
  },
  [Events.HeadlineArchived] = {
    AttachMaybeDeleteArchived,
  },
}

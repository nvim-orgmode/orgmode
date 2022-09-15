local Events = require('orgmode.events.types')
local AlignTags = require('orgmode.events.listeners.align_tags')

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
}

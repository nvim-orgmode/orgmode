---@param event OrgHeadlineArchivedEvent
return function(event)
  require('orgmode').attach:maybe_delete_archived(event.headline)
end

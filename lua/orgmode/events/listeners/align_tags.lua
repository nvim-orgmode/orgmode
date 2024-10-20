---@param event OrgTodoChangedEvent | OrgHeadlineDemotedEvent | OrgHeadlinePromotedEvent
return function(event)
  event.headline:align_tags()
end

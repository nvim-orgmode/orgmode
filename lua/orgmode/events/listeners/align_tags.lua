---@param event TodoChangedEvent | HeadlineDemotedEvent | HeadlinePromotedEvent
return function(event)
  event.headline:align_tags()
end

---@param event OrgTodoChangedEvent
return function(event)
  if event.headline:is_done() and not event.was_done and (event.old_todo_state and event.old_todo_state ~= '') then
    event.headline:clock_out()
  end
end

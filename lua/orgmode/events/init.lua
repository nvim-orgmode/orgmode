local Events = require('orgmode.events.types')
local Listeners = require('orgmode.events.listeners')

---@class OrgEventManager
local EventManager = {
  initialized = false,
  _listeners = {},
  event = Events,
}

---@param event OrgEvent
function EventManager.dispatch(event)
  if EventManager._listeners[event.type] then
    for _, listener in ipairs(EventManager._listeners[event.type]) do
      listener(event)
    end
  end
end

---@param event OrgEvent
---@param listener fun(...)
function EventManager.listen(event, listener)
  if not EventManager._listeners[event.type] then
    EventManager._listeners[event.type] = {}
  end
  if not vim.tbl_contains(EventManager._listeners[event.type], listener) then
    table.insert(EventManager._listeners[event.type], listener)
  end
end

function EventManager.init()
  if EventManager.initialized then
    return
  end
  for event, listeners in pairs(Listeners) do
    for _, listener in ipairs(listeners) do
      EventManager.listen(event, listener)
    end
  end
  EventManager.initialized = true
  return EventManager
end

return EventManager

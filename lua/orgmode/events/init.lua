local Events = require('orgmode.events.types')
local Listeners = require('orgmode.events.listeners')

---@class OrgEventManager
---@field private initialized boolean
---@field private _listeners table<string, fun(...:any)[]>
local EventManager = {
  initialized = false,
  _listeners = vim.defaulttable(function()
    return {}
  end),
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
  local listeners = EventManager._listeners[event.type]
  if not vim.tbl_contains(listeners, listener) then
    table.insert(listeners, listener)
  end
end

function EventManager.init()
  if EventManager.initialized then
    return EventManager
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

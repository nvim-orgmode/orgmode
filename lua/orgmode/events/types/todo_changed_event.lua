---@class TodoChangedEvent: Event
---@field type string
---@field section Section
---@field headline Headline
---@field old_todo_state? string
---@field is_done? boolean
local TodoChangedEvent = {
  type = 'orgmode.todo_changed',
}

---@param section Section
---@param headline Headline
---@param old_todo_state? string
---@param is_done? boolean
function TodoChangedEvent:new(section, headline, old_todo_state, is_done)
  local obj = setmetatable({}, self)
  self.__index = self
  obj.section = section
  obj.headline = headline
  obj.old_todo_state = old_todo_state
  obj.is_done = is_done
  return obj
end

return TodoChangedEvent

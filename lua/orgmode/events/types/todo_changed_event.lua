---@class OrgTodoChangedEvent: OrgEvent
---@field type string
---@field headline OrgHeadline
---@field old_todo_state? string
---@field is_done? boolean
local TodoChangedEvent = {
  type = 'orgmode.todo_changed',
}

---@param headline OrgHeadline
---@param old_todo_state? string
---@param is_done? boolean
function TodoChangedEvent:new(headline, old_todo_state, is_done)
  local obj = setmetatable({}, self)
  self.__index = self
  obj.headline = headline
  obj.old_todo_state = old_todo_state
  obj.is_done = is_done
  return obj
end

return TodoChangedEvent

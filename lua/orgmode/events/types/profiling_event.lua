---@class OrgProfilingEvent: OrgEvent
---@field type string Always 'orgmode.profiling'
---@field action 'start'|'mark'|'complete' The profiling action
---@field category string Session category (e.g., 'init', 'files', 'plugin:my-plugin')
---@field label string Human-readable label
---@field payload? table Optional additional data
local ProfilingEvent = {
  type = 'orgmode.profiling',
}
ProfilingEvent.__index = ProfilingEvent

---@param action 'start'|'mark'|'complete'
---@param category string
---@param label string
---@param payload? table
---@return OrgProfilingEvent
function ProfilingEvent:new(action, category, label, payload)
  local obj = setmetatable({}, self)
  obj.action = action
  obj.category = category
  obj.label = label
  obj.payload = payload
  return obj
end

---@param category string
---@param label string
---@param payload? table
---@return OrgProfilingEvent
function ProfilingEvent:start(category, label, payload)
  return self:new('start', category, label, payload)
end

---@param category string
---@param label string
---@param payload? table
---@return OrgProfilingEvent
function ProfilingEvent:mark(category, label, payload)
  return self:new('mark', category, label, payload)
end

---@param category string
---@param label string
---@param payload? table
---@return OrgProfilingEvent
function ProfilingEvent:complete(category, label, payload)
  return self:new('complete', category, label, payload)
end

return ProfilingEvent

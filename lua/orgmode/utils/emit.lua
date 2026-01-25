local EventManager = require('orgmode.events')
local ProfilingEvent = require('orgmode.events.types.profiling_event')

local M = {}

-- Events dispatch regardless of profiler state; profiler decides whether to process
---@param action 'start'|'mark'|'complete'
---@param category string
---@param label string
---@param payload? table
function M.profile(action, category, label, payload)
  EventManager.dispatch(ProfilingEvent[action](ProfilingEvent, category, label, payload))
end

return M

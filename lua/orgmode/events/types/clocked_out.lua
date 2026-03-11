---@class OrgClockedOutEvent: OrgEvent
---@field headline? OrgHeadline
local ClockedOutEvent = {
  type = 'orgmode.clocked_out',
}
ClockedOutEvent.__index = ClockedOutEvent

---@param headline OrgHeadline
function ClockedOutEvent:new(headline)
  return setmetatable({
    headline = headline,
  }, self)
end

return ClockedOutEvent

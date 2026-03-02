---@class OrgClockedInEvent: OrgEvent
---@field headline? OrgHeadline
local ClockedInEvent = {
  type = 'orgmode.clocked_in',
}
ClockedInEvent.__index = ClockedInEvent

---@param headline OrgHeadline
function ClockedInEvent:new(headline)
  return setmetatable({
    headline = headline,
  }, self)
end

return ClockedInEvent

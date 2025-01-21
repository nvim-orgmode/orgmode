---@class OrgHeadingToggledEvent: OrgEvent
---@field headline? OrgHeadline
---@field line? number
---@field action 'line_to_headline' | 'headline_to_line' | 'line_to_child_headline'
local HeadingToggledEvent = {
  type = 'orgmode.heading_toggled',
}
HeadingToggledEvent.__index = HeadingToggledEvent

---@param line number
---@param action 'line_to_headline' | 'headline_to_line' | 'line_to_child_headline'
---@param headline? OrgHeadline
function HeadingToggledEvent:new(line, action, headline)
  return setmetatable({
    line = line,
    headline = headline,
    action = action,
  }, self)
end

return HeadingToggledEvent

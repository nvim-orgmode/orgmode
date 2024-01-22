---@class OrgHeadlineDemotedEvent: OrgEvent
---@field type string
---@field headline OrgHeadline
---@field old_headline? string

local HeadlineDemotedEvent = {
  type = 'orgmode.headline_demoted',
}

---@param headline OrgHeadline
---@param old_level number
function HeadlineDemotedEvent:new(headline, old_level)
  local obj = setmetatable({}, self)
  self.__index = self
  obj.headline = headline
  obj.old_level = old_level
  return obj
end

return HeadlineDemotedEvent

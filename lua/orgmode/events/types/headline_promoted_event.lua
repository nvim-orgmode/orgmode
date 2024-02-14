---@class OrgHeadlinePromotedEvent: OrgEvent
---@field type string
---@field headline OrgHeadline
---@field old_headline? string

local HeadlinePromotedEvent = {
  type = 'orgmode.headline_promoted',
}

---@param headline OrgHeadline
---@param old_level number
function HeadlinePromotedEvent:new(headline, old_level)
  local obj = setmetatable({}, self)
  self.__index = self
  obj.headline = headline
  obj.old_level = old_level
  return obj
end

return HeadlinePromotedEvent

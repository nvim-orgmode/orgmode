---@class HeadlineDemotedEvent: Event
---@field type string
---@field section Section
---@field headline Headline
---@field old_headline? string

local HeadlineDemotedEvent = {
  type = 'orgmode.headline_demoted',
}

---@param section Section
---@param headline Headline
---@param old_level number
function HeadlineDemotedEvent:new(section, headline, old_level)
  local obj = setmetatable({}, self)
  self.__index = self
  obj.section = section
  obj.headline = headline
  obj.old_level = old_level
  return obj
end

return HeadlineDemotedEvent

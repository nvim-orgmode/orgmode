---@class OrgHeadlineArchivedEvent: OrgEvent
---@field type string
---@field headline OrgHeadline
---@field destination_file OrgFile
local HeadlineArchivedEvent = {
  type = 'orgmode.headline_archived',
}

---@param headline OrgHeadline
---@param destination_file OrgFile
---@return OrgHeadlineArchivedEvent
function HeadlineArchivedEvent:new(headline, destination_file)
  local obj = setmetatable({}, self)
  self.__index = self
  obj.headline = headline
  obj.destination_file = destination_file
  return obj
end

return HeadlineArchivedEvent

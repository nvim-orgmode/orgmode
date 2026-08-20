---@class OrgAttachOpenedEvent: OrgEvent
---@field type string
---@field node OrgAttachNode
---@field path string
local AttachOpenedEvent = {
  type = 'orgmode.attach_opened',
}

---@param node OrgAttachNode
---@param path string
---@return OrgAttachOpenedEvent
function AttachOpenedEvent:new(node, path)
  local obj = setmetatable({}, self)
  self.__index = self
  obj.node = node
  obj.path = path
  return obj
end

return AttachOpenedEvent

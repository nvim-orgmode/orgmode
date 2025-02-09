---@class OrgAttachChangedEvent: OrgEvent
---@field type string
---@field node OrgAttachNode
---@field attach_dir string
local AttachChangedEvent = {
  type = 'orgmode.attach_changed',
}

---@param node OrgAttachNode
---@param attach_dir string
---@return OrgAttachChangedEvent
function AttachChangedEvent:new(node, attach_dir)
  local obj = setmetatable({}, self)
  self.__index = self
  obj.node = node
  obj.attach_dir = attach_dir
  return obj
end

return AttachChangedEvent

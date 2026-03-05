---@class OrgNoteAddedEvent: OrgEvent
---@field type string
---@field headline OrgHeadline
---@field note string[]
local NoteAddedEvent = {
  type = 'orgmode.note_added',
}

---@param headline OrgHeadline
---@param note string[]
function NoteAddedEvent:new(headline, note)
  local obj = setmetatable({}, self)
  self.__index = self
  obj.headline = headline
  obj.note = note
  return obj
end

return NoteAddedEvent

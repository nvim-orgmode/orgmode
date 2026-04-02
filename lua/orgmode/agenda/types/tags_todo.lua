local OrgAgendaTagsType = require('orgmode.agenda.types.tags')

---@class OrgAgendaTagsTodoType:OrgAgendaTagsType
local OrgAgendaTagsTodoType = {}
OrgAgendaTagsTodoType.__index = OrgAgendaTagsTodoType

---@param opts OrgAgendaTagsTypeOpts
function OrgAgendaTagsTodoType:new(opts)
  opts.todo_only = true
  setmetatable(self, { __index = OrgAgendaTagsType })
  local obj = OrgAgendaTagsType:new(opts)
  if not obj then
    return nil
  end
  setmetatable(obj, self)
  obj.prefix_key = 'tags_todo'
  return obj
end

return OrgAgendaTagsTodoType

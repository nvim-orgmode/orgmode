---@diagnostic disable: inject-field
local OrgAgendaTodosType = require('orgmode.agenda.types.todo')

---@class OrgAgendaSearchTypeOpts:OrgAgendaTodosTypeOpts
---@field headline_search? string

---@class OrgAgendaSearchType:OrgAgendaTodosType
---@field headline_search? string
local OrgAgendaSearchType = {}
OrgAgendaSearchType.__index = OrgAgendaSearchType

---@param opts OrgAgendaSearchTypeOpts
function OrgAgendaSearchType:new(opts)
  opts.todo_only = false
  opts.subheader = 'Press "r" to update search'
  setmetatable(self, { __index = OrgAgendaTodosType })
  local obj = OrgAgendaTodosType:new(opts)
  setmetatable(obj, self)
  obj.headline_search = self.headline_search
  if not opts.headline_search or opts.headline_search == '' then
    obj.headline_search = self:get_search_term()
  end
  return obj
end

function OrgAgendaSearchType:get_file_headlines(file)
  return file:find_headlines_matching_search_term(self.headline_search or '', false, true)
end

function OrgAgendaSearchType:get_search_term()
  return vim.fn.OrgmodeInput('Enter search term: ', self.headline_search or '')
end

function OrgAgendaSearchType:redo()
  -- Skip prompt for custom views
  if self.is_custom then
    return self
  end
  self.headline_search = self:get_search_term()
  return self
end

return OrgAgendaSearchType

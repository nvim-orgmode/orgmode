---@diagnostic disable: inject-field
local OrgAgendaTodosType = require('orgmode.agenda.types.todo')
local Input = require('orgmode.ui.input')

---@class OrgAgendaSearchTypeOpts:OrgAgendaTodosTypeOpts
---@field headline_query? string

---@class OrgAgendaSearchType:OrgAgendaTodosType
---@field headline_query? string
local OrgAgendaSearchType = {}
OrgAgendaSearchType.__index = OrgAgendaSearchType

---@param opts OrgAgendaSearchTypeOpts
function OrgAgendaSearchType:new(opts)
  opts.todo_only = false
  opts.subheader = 'Press "r" to update search'
  setmetatable(self, { __index = OrgAgendaTodosType })
  local obj = OrgAgendaTodosType:new(opts)
  setmetatable(obj, self)
  obj.headline_query = self.headline_query
  return obj
end

function OrgAgendaSearchType:prepare()
  if not self.headline_query or self.headline_query == '' then
    return self:get_search_term()
  end
end

function OrgAgendaSearchType:get_file_headlines(file)
  return file:find_headlines_matching_search_term(self.headline_query or '', false, true)
end

function OrgAgendaSearchType:get_search_term()
  return Input.open('Enter search term: ', self.headline_query or ''):next(function(value)
    if not value then
      return false
    end
    self.headline_query = value
    return self
  end)
end

function OrgAgendaSearchType:redraw()
  -- Skip prompt for custom views
  if self.id then
    return self
  end
  return self:get_search_term()
end

return OrgAgendaSearchType

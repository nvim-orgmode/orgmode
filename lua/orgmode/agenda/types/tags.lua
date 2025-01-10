---@diagnostic disable: inject-field
local utils = require('orgmode.utils')
local Search = require('orgmode.files.elements.search')
local OrgAgendaTodosType = require('orgmode.agenda.types.todo')

---@class OrgAgendaTagsTypeOpts:OrgAgendaTodosTypeOpts
---@field search_query? string

---@class OrgAgendaTagsType:OrgAgendaTodosType
local OrgAgendaTagsType = {}
OrgAgendaTagsType.__index = OrgAgendaTagsType

---@param opts OrgAgendaTagsTypeOpts
function OrgAgendaTagsType:new(opts)
  opts.todo_only = opts.todo_only or false
  opts.subheader = 'Press "r" to update search'
  local search_query = opts.search_query
  if not search_query or search_query == '' then
    search_query = self:get_tags(opts.files)
    if not search_query then
      return nil
    end
  end

  setmetatable(self, { __index = OrgAgendaTodosType })
  local obj = OrgAgendaTodosType:new(opts)
  setmetatable(obj, self)
  obj.search_query = search_query
  obj.header = 'Headlines with TAGS match: ' .. obj.search_query
  return obj
end

function OrgAgendaTagsType:get_file_headlines(file)
  return file:apply_search(Search:new(self.search_query or ''), self.todo_only)
end

---@param files? OrgFiles
function OrgAgendaTagsType:get_tags(files)
  local tags = vim.fn.OrgmodeInput('Match: ', self.search_query or '', function(arg_lead)
    return utils.prompt_autocomplete(arg_lead, (files or self.files):get_tags())
  end)
  if vim.trim(tags) == '' then
    return utils.echo_warning('Invalid tag.')
  end
  return tags
end

function OrgAgendaTagsType:redo()
  if self.is_custom then
    return self
  end
  self.search_query = self:get_tags() or ''
  self.header = 'Headlines with TAGS match: ' .. self.search_query
  return self
end

return OrgAgendaTagsType

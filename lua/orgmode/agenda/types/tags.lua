---@diagnostic disable: inject-field
local utils = require('orgmode.utils')
local Search = require('orgmode.files.elements.search')
local OrgAgendaTodosType = require('orgmode.agenda.types.todo')

---@class OrgAgendaTagsTypeOpts:OrgAgendaTodosTypeOpts
---@field match_query? string

---@class OrgAgendaTagsType:OrgAgendaTodosType
local OrgAgendaTagsType = {}
OrgAgendaTagsType.__index = OrgAgendaTagsType

---@param opts OrgAgendaTagsTypeOpts
function OrgAgendaTagsType:new(opts)
  opts.todo_only = opts.todo_only or false
  opts.subheader = 'Press "r" to update search'
  local match_query = opts.match_query
  if not match_query or match_query == '' then
    match_query = self:get_tags(opts.files)
    if not match_query then
      return nil
    end
  end

  setmetatable(self, { __index = OrgAgendaTodosType })
  local obj = OrgAgendaTodosType:new(opts)
  setmetatable(obj, self)
  obj.match_query = match_query
  obj.header = 'Headlines with TAGS match: ' .. obj.match_query
  return obj
end

function OrgAgendaTagsType:get_file_headlines(file)
  return file:apply_search(Search:new(self.match_query or ''), self.todo_only)
end

---@param files? OrgFiles
function OrgAgendaTagsType:get_tags(files)
  local tags = vim.fn.OrgmodeInput('Match: ', self.match_query or '', function(arg_lead)
    return utils.prompt_autocomplete(arg_lead, (files or self.files):get_tags())
  end)
  if vim.trim(tags) == '' then
    return utils.echo_warning('Invalid tag.')
  end
  return tags
end

function OrgAgendaTagsType:redo()
  -- Skip prompt for custom views
  if self.is_custom then
    return self
  end
  self.match_query = self:get_tags() or ''
  self.header = 'Headlines with TAGS match: ' .. self.match_query
  return self
end

return OrgAgendaTagsType

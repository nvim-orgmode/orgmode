---@class OrgLinks:OrgLinkType
---@field private files OrgFiles
---@field private types OrgLinkType[]
---@field private types_by_name table<string, OrgLinkType>
local OrgLinks = {}
OrgLinks.__index = OrgLinks

---@param opts { files: OrgFiles }
function OrgLinks:new(opts)
  local this = setmetatable({
    files = opts.files,
    types = {},
    types_by_name = {},
  }, OrgLinks)
  this:setup_builtin_types()
  return this
end

function OrgLinks:setup_builtin_types()
  self:add_type(require('orgmode.org.links.types.id'):new({ files = self.files }))
end

function OrgLinks:add_type(link_type)
  if self.types_by_name[link_type:get_name()] then
    error('Link type ' .. link_type:get_name() .. ' already exists')
  end
  self.types_by_name[link_type:get_name()] = link_type
  table.insert(self.types, link_type)
end

---@param link string
---@return boolean
function OrgLinks:follow(link)
  for _, source in ipairs(self.types) do
    if source:follow(link) then
      return true
    end
  end
  return false
end

return OrgLinks

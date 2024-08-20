local config = require('orgmode.config')
local utils = require('orgmode.utils')
local OrgLinkUrl = require('orgmode.org.links.url')

---@class OrgLinks:OrgLinkType
---@field private files OrgFiles
---@field private types OrgLinkType[]
---@field private types_by_name table<string, OrgLinkType>
---@field private stored_links table<string, string>
---@field private headline_search OrgLinkHeadlineSearch
local OrgLinks = {
  stored_links = {},
}
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

---@param link string
---@return boolean
function OrgLinks:follow(link)
  for _, source in ipairs(self.types) do
    if source:follow(link) then
      return true
    end
  end

  local org_link_url = OrgLinkUrl:new(link)
  if org_link_url.protocol and org_link_url.protocol ~= 'file' then
    utils.echo_warning(string.format('Unsupported link protocol: %q', org_link_url.protocol))
    return false
  end

  return self.headline_search:follow(link)
end

---@param headline OrgHeadline
function OrgLinks:store_link_to_headline(headline)
  self.stored_links[self:get_link_to_headline(headline)] = headline:get_title()
end

---@param headline OrgHeadline
---@return string
function OrgLinks:get_link_to_headline(headline)
  local title = headline:get_title()

  if config.org_id_link_to_org_use_id then
    local id = headline:id_get_or_create()
    if id then
      return ('id:%s::*%s'):format(id, title)
    end
  end

  return ('file:%s::*%s'):format(headline.file.filename, title)
end

---@param file OrgFile
---@return string
function OrgLinks:get_link_to_file(file)
  local title = file:get_title()

  if config.org_id_link_to_org_use_id then
    local id = file:id_get_or_create()
    if id then
      return ('id:%s::*%s'):format(id, title)
    end
  end

  return ('file:%s::*%s'):format(file.filename, title)
end

function OrgLinks:setup_builtin_types()
  self:add_type(require('orgmode.org.links.types.http'):new({ files = self.files }))
  self:add_type(require('orgmode.org.links.types.id'):new({ files = self.files }))
  self:add_type(require('orgmode.org.links.types.line_number'):new({ files = self.files }))
  self:add_type(require('orgmode.org.links.types.custom_id'):new({ files = self.files }))
  self:add_type(require('orgmode.org.links.types.headline'):new({ files = self.files }))

  self.headline_search = require('orgmode.org.links.types.headline_search'):new({ files = self.files })
end

function OrgLinks:add_type(link_type)
  if self.types_by_name[link_type:get_name()] then
    error('Link type ' .. link_type:get_name() .. ' already exists')
  end
  self.types_by_name[link_type:get_name()] = link_type
  table.insert(self.types, link_type)
end

return OrgLinks

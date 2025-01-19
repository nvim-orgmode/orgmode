local utils = require('orgmode.utils')
local link_utils = require('orgmode.org.links.utils')

---@class OrgLinkId:OrgLinkType
---@field private files OrgFiles
local OrgLinkId = {}
OrgLinkId.__index = OrgLinkId

---@param opts { files: OrgFiles }
function OrgLinkId:new(opts)
  local this = setmetatable({
    files = opts.files,
  }, OrgLinkId)
  return this
end

---@return string
function OrgLinkId:get_name()
  return 'id'
end

---@param link string
---@return boolean
function OrgLinkId:follow(link)
  local id = self:_parse(link)
  if not id then
    return false
  end

  local files = self.files:find_files_with_property('id', id)
  if #files > 0 then
    if #files > 1 then
      utils.echo_warning(string.format('Multiple files found with id: %s, jumping to first one found', id))
    end
    return link_utils.goto_file(files[1])
  end

  local headlines = self.files:find_headlines_with_property('id', id)
  if #headlines == 0 then
    utils.echo_warning(string.format('No headline found with id: %s', id))
    return true
  end
  if #headlines > 1 then
    utils.echo_warning(string.format('Multiple headlines found with id: %s', id))
    return true
  end
  local headline = headlines[1]
  utils.goto_headline(headline)
  return true
end

---@return string[]
function OrgLinkId:autocomplete(_)
  return {}
end

---@private
---@param link string
---@return string?
function OrgLinkId:_parse(link)
  return link:match('^id:(.+)$')
end

return OrgLinkId

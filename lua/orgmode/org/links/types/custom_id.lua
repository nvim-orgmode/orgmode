local utils = require('orgmode.utils')
local link_utils = require('orgmode.org.links.utils')

---@class OrgLinkCustomId:OrgLinkType
---@field private files OrgFiles
local OrgLinkCustomId = {}
OrgLinkCustomId.__index = OrgLinkCustomId

---@param opts { files: OrgFiles }
function OrgLinkCustomId:new(opts)
  local this = setmetatable({
    files = opts.files,
  }, OrgLinkCustomId)
  return this
end

function OrgLinkCustomId:get_name()
  return 'custom_id'
end

---@param link string
---@return boolean
function OrgLinkCustomId:follow(link)
  local opts = self:_parse(link)
  if not opts then
    return false
  end

  local headlines = opts.file:find_headlines_with_property('CUSTOM_ID', opts.custom_id)
  return link_utils.goto_oneof_headlines(headlines)
end

---@private
---@param link string
---@return { custom_id: string, file: OrgFile  } | nil
function OrgLinkCustomId:_parse(link)
  local custom_id = link:match('^#(.+)$')
  if custom_id then
    return {
      custom_id = custom_id,
      file = self.files:get_current_file(),
    }
  end

  -- TODO: Add support for file format
  return nil
end

return OrgLinkCustomId

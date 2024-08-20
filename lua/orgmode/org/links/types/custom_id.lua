local utils = require('orgmode.utils')
local OrgLinkUrl = require('orgmode.org.links.url')
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

  local file = self.files:load_file_sync(opts.file_path)
  local err_msg = 'No headline found with custom id: ' .. opts.custom_id

  if file then
    local headlines = file:find_headlines_with_property('CUSTOM_ID', opts.custom_id)
    return link_utils.goto_oneof_headlines(headlines, file.filename, err_msg)
  end

  return link_utils.open_file_and_search(opts.file_path, opts.custom_id)
end

---@private
---@param link string
---@return { custom_id: string, file_path: string  } | nil
function OrgLinkCustomId:_parse(link)
  local link_url = OrgLinkUrl:new(link)

  local target = link_url:get_target()
  local path = link_url:get_path()
  local custom_id = (target and target:match('^#(.+)$')) or (path and path:match('^#(.+)$'))

  if custom_id then
    return {
      custom_id = custom_id,
      file_path = link_url:get_file_path() or utils.current_file_path(),
    }
  end

  return nil
end

return OrgLinkCustomId

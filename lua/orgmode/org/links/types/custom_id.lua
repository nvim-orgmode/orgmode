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

---@return string
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

  if file and vim.trim(opts.custom_id) ~= '' then
    local headlines = file:find_headlines_with_property('CUSTOM_ID', opts.custom_id)
    return link_utils.goto_oneof_headlines(
      headlines,
      file.filename,
      'No headline found with custom id: ' .. opts.custom_id
    )
  end

  return link_utils.open_file_and_search(opts.file_path, opts.custom_id)
end

---@param link string
---@return string[]
function OrgLinkCustomId:autocomplete(link)
  local opts = self:_parse(link)
  if not opts then
    return {}
  end

  local file = self.files:load_file_sync(opts.file_path)

  if not file then
    return {}
  end

  local headlines = file:find_headlines_with_property_matching('CUSTOM_ID', opts.custom_id)
  local prefix = opts.type == 'internal' and '' or opts.link_url:get_path_with_protocol() .. '::'

  return vim.tbl_map(function(headline)
    local custom_id = headline:get_property('custom_id')
    return prefix .. '#' .. custom_id
  end, headlines)
end

---@private
---@param link string
---@return { custom_id: string, file_path: string, link_url: OrgLinkUrl, type: 'file' | 'internal'  } | nil
function OrgLinkCustomId:_parse(link)
  local link_url = OrgLinkUrl:new(link)

  local target = link_url:get_target()
  local path = link_url:get_path()

  local file_path_custom_id = target and target:match('^#(.*)$')
  local current_file_custom_id = path and path:match('^#(.*)$')

  if file_path_custom_id then
    local file_path = link_url:get_file_path()
    if not file_path then
      return nil
    end
    return {
      custom_id = file_path_custom_id,
      file_path = file_path,
      link_url = link_url,
      type = 'file',
    }
  end

  if current_file_custom_id then
    return {
      custom_id = current_file_custom_id,
      file_path = utils.current_file_path(),
      link_url = link_url,
      type = 'internal',
    }
  end

  return nil
end

return OrgLinkCustomId

local utils = require('orgmode.utils')
local OrgLinkUrl = require('orgmode.org.links.url')
local link_utils = require('orgmode.org.links.utils')

---@class OrgLinkHeadline:OrgLinkType
---@field private files OrgFiles
local OrgLinkHeadline = {}
OrgLinkHeadline.__index = OrgLinkHeadline

---@param opts { files: OrgFiles }
function OrgLinkHeadline:new(opts)
  local this = setmetatable({
    files = opts.files,
  }, OrgLinkHeadline)
  return this
end

---@return string
function OrgLinkHeadline:get_name()
  return 'headline'
end

---@param link string
---@return boolean
function OrgLinkHeadline:follow(link)
  local opts = self:_parse(link)
  if not opts then
    return false
  end

  local org_file = self.files:load_file_sync(opts.file_path)

  if org_file and vim.trim(opts.headline) ~= '' then
    local headlines = org_file:find_headlines_by_title(opts.headline)
    return link_utils.goto_oneof_headlines(headlines, opts.file_path, 'No headline found with title: ' .. opts.headline)
  end

  return link_utils.open_file_and_search(opts.file_path, opts.headline)
end

---@param link string
---@return string[]
function OrgLinkHeadline:autocomplete(link)
  local opts = self:_parse(link)
  if not opts then
    return {}
  end

  local file = self.files:load_file_sync(opts.file_path)

  if not file then
    return {}
  end

  local headlines = file:find_headlines_by_title(opts.headline)
  local prefix = opts.type == 'internal' and '' or opts.link_url:get_path_with_protocol() .. '::'

  return vim.tbl_map(function(headline)
    local title = headline:get_title()
    return prefix .. '*' .. title
  end, headlines)
end

---@private
---@param link string
---@return { headline: string, file_path: string, link_url: OrgLinkUrl, type: 'file' | 'internal'  } | nil
function OrgLinkHeadline:_parse(link)
  local link_url = OrgLinkUrl:new(link)

  local target = link_url:get_target()
  local path = link_url:get_path()

  local file_path_headline = target and target:match('^%*(.*)$')
  local current_file_headline = path and path:match('^%*(.*)$')

  if file_path_headline then
    local file_path = link_url:get_file_path()
    if not file_path then
      return nil
    end
    return {
      headline = file_path_headline,
      file_path = file_path,
      link_url = link_url,
      type = 'file',
    }
  end

  if current_file_headline then
    return {
      headline = current_file_headline,
      file_path = utils.current_file_path(),
      link_url = link_url,
      type = 'internal',
    }
  end

  return nil
end

return OrgLinkHeadline

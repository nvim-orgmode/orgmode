local utils = require('orgmode.utils')

---@class OrgLinkHttp:OrgLinkType
---@field private files OrgFiles
local OrgLinkHttp = {}
OrgLinkHttp.__index = OrgLinkHttp

---@param opts { files: OrgFiles }
function OrgLinkHttp:new(opts)
  local this = setmetatable({
    files = opts.files,
  }, OrgLinkHttp)
  return this
end

---@return string
function OrgLinkHttp:get_name()
  return 'http'
end

---@param link string
---@return boolean
function OrgLinkHttp:follow(link)
  local url = self:_parse(link)
  if not url then
    return false
  end

  if vim.ui['open'] then
    vim.ui.open(url)
    return true
  end

  if not vim.g.loaded_netrwPlugin then
    utils.echo_warning('Netrw plugin must be loaded in order to open urls.')
    return false
  end

  vim.fn['netrw#BrowseX'](url, vim.fn['netrw#CheckIfRemote']())
  return true
end

---@return string[]
function OrgLinkHttp:autocomplete(_)
  return {}
end

---@private
---@param link string
---@return string | nil
function OrgLinkHttp:_parse(link)
  local is_url = link:match('^https?://(.+)$')
  if is_url then
    return link
  end

  return nil
end

return OrgLinkHttp

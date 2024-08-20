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

  local headlines = opts.file:find_headlines_by_title(opts.headline_title)
  return link_utils.goto_oneof_headlines(headlines)
end

---@private
---@param link string
---@return { headline_title: string, file: OrgFile  } | nil
function OrgLinkHeadline:_parse(link)
  local headline_title = link:match('^%*(.+)$')
  if headline_title then
    return {
      headline_title = headline_title,
      file = self.files:get_current_file(),
    }
  end

  -- TODO: Add support for file format
  return nil
end

return OrgLinkHeadline

local utils = require('orgmode.utils')
local OrgLinkUrl = require('orgmode.org.links.url')
local link_utils = require('orgmode.org.links.utils')

---@class OrgLinkHeadlineSearch:OrgLinkType
---@field private files OrgFiles
local OrgLinkHeadlineSearch = {}
OrgLinkHeadlineSearch.__index = OrgLinkHeadlineSearch

---@param opts { files: OrgFiles }
function OrgLinkHeadlineSearch:new(opts)
  local this = setmetatable({
    files = opts.files,
  }, OrgLinkHeadlineSearch)
  return this
end

function OrgLinkHeadlineSearch:get_name()
  return 'headline'
end

---@param link string
---@return boolean
function OrgLinkHeadlineSearch:follow(link)
  local opts = self:_parse(link)
  if not opts then
    return false
  end

  local file = self.files:load_file_sync(opts.file_path)

  if file then
    local pattern = ('<<<?(%s[^>]*)>>>?'):format(opts.headline_text):lower()
    local headlines = file:find_headlines_matching_search_term(pattern, true)
    if #headlines == 0 then
      headlines = file:find_headlines_by_title(opts.headline_text)
    end

    return link_utils.goto_oneof_headlines(
      headlines,
      file.filename,
      'No headline found with title: ' .. opts.headline_text
    )
  end

  return link_utils.open_file_and_search(opts.file_path, opts.headline_text)
end

---@private
---@param link string
---@return { headline_text: string, file_path: string  } | nil
function OrgLinkHeadlineSearch:_parse(link)
  local link_url = OrgLinkUrl:new(link)

  local target = link_url:get_target()
  local path = link_url:get_path()
  local headline_text = target or path

  if headline_text and headline_text ~= '' then
    return {
      headline_text = headline_text,
      file_path = link_url:get_file_path() or utils.current_file_path(),
    }
  end

  return nil
end

return OrgLinkHeadlineSearch

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

---@return string
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
  local is_file_only = opts.type == 'file' and not opts.target

  if file then
    if is_file_only then
      return link_utils.goto_file(file)
    end

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

  local search_text = opts.headline_text

  if is_file_only then
    search_text = ''
  end

  return link_utils.open_file_and_search(opts.file_path, search_text)
end

---@param link string
---@return string[]
function OrgLinkHeadlineSearch:autocomplete(link)
  local opts = self:_parse(link)
  if not opts then
    return {}
  end

  if opts.type == 'file' and not opts.target then
    local filenames = self.files:filenames()
    local valid_filenames = {}
    for _, f in ipairs(filenames) do
      if f:find('^' .. opts.file_path) then
        f = f:gsub('^' .. opts.file_path, opts.link_url.path)
        table.insert(valid_filenames, f)
      end
    end

    local prefix = opts.link_url:get_protocol() == 'file' and 'file:' or ''

    return vim.tbl_map(function(path)
      return prefix .. path
    end, valid_filenames)
  end

  local file = self.files:load_file_sync(opts.file_path)

  if not file then
    return {}
  end

  local pattern = ('<<<?(%s[^>]*)>>>?'):format(opts.headline_text):lower()
  local headlines = vim.tbl_map(function(headline)
    return headline:get_title()
  end, file:find_headlines_matching_search_term(pattern, true))

  utils.concat(
    headlines,
    vim.tbl_map(function(headline)
      return headline:get_title()
    end, file:find_headlines_by_title(opts.headline_text)),
    true
  )
  local prefix = opts.type == 'internal' and '' or opts.link_url:get_path_with_protocol() .. '::'

  return vim.tbl_map(function(headline_title)
    return prefix .. headline_title
  end, headlines)
end

---@private
---@param link string
---@return { headline_text: string, file_path: string, link_url: OrgLinkUrl, type: 'file' | 'internal', target: string | nil  } | nil
function OrgLinkHeadlineSearch:_parse(link)
  local link_url = OrgLinkUrl:new(link)

  local target = link_url:get_target()
  local path = link_url:get_path()
  local headline_text = target or path

  if headline_text then
    local file_path = link_url:get_file_path()
    return {
      headline_text = headline_text,
      file_path = file_path or utils.current_file_path(),
      link_url = link_url,
      target = target,
      type = file_path and 'file' or 'internal',
    }
  end

  return nil
end

return OrgLinkHeadlineSearch

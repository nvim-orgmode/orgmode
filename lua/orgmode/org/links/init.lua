local config = require('orgmode.config')
local utils = require('orgmode.utils')
local OrgLinkUrl = require('orgmode.org.links.url')
local OrgHyperlink = require('orgmode.org.links.hyperlink')

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
  this:_setup_builtin_types()
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
  if org_link_url.protocol and org_link_url.protocol ~= 'file' and org_link_url.protocol ~= 'id' then
    utils.echo_warning(string.format('Unsupported link protocol: %q', org_link_url.protocol))
    return false
  end

  return self.headline_search:follow(link)
end

---@param link string
---@return string[]
function OrgLinks:autocomplete(link)
  local pattern = '^' .. vim.pesc(link:lower())

  local items = vim.tbl_filter(function(stored_link)
    return stored_link:lower():match(pattern)
  end, vim.tbl_keys(self.stored_links))

  for _, source in ipairs(self.types) do
    utils.concat(items, source:autocomplete(link))
  end

  utils.concat(items, self.headline_search:autocomplete(link))
  return items
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

---@param link_location string
function OrgLinks:insert_link(link_location)
  local selected_link = OrgHyperlink:new(link_location)
  local desc = selected_link.url:get_target()
  if desc and (desc:match('^%*') or desc:match('^#')) then
    desc = desc:sub(2)
  end

  if selected_link.url:get_protocol() == 'id' then
    link_location = ('id:%s'):format(selected_link.url:get_path())
  end

  local link_description = vim.trim(vim.fn.OrgmodeInput('Description: ', desc or ''))

  link_location = '[' .. vim.trim(link_location) .. ']'

  if link_description ~= '' then
    link_description = '[' .. link_description .. ']'
  end

  local insert_from
  local insert_to
  local target_col = #link_location + #link_description + 2

  -- check if currently on link
  local link, position = OrgHyperlink.at_cursor()
  if link and position then
    insert_from = position.from - 1
    insert_to = position.to + 1
    target_col = target_col + position.from
  else
    local colnr = vim.fn.col('.')
    insert_from = colnr
    insert_to = colnr + 1
    target_col = target_col + colnr
  end

  local linenr = vim.fn.line('.') or 0
  local curr_line = vim.fn.getline(linenr)
  local new_line = string.sub(curr_line, 0, insert_from)
    .. '['
    .. link_location
    .. link_description
    .. ']'
    .. string.sub(curr_line, insert_to, #curr_line)

  vim.fn.setline(linenr, new_line)
  vim.fn.cursor(linenr, target_col)
end

---@param link_type OrgLinkType
function OrgLinks:add_type(link_type)
  if self.types_by_name[link_type:get_name()] then
    error('Link type ' .. link_type:get_name() .. ' already exists')
  end
  self.types_by_name[link_type:get_name()] = link_type
  table.insert(self.types, link_type)
end

---@private
function OrgLinks:_setup_builtin_types()
  self:add_type(require('orgmode.org.links.types.http'):new({ files = self.files }))
  self:add_type(require('orgmode.org.links.types.id'):new({ files = self.files }))
  self:add_type(require('orgmode.org.links.types.line_number'):new({ files = self.files }))
  self:add_type(require('orgmode.org.links.types.custom_id'):new({ files = self.files }))
  self:add_type(require('orgmode.org.links.types.headline'):new({ files = self.files }))

  self.headline_search = require('orgmode.org.links.types.headline_search'):new({ files = self.files })
end

return OrgLinks

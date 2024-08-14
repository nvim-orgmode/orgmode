local Org = require('orgmode')
local utils = require('orgmode.utils')
local Link = require('orgmode.org.links.link_handler')

---@class OrgLinkHandlerInternal:OrgLinkHandler
local Internal = Link:new()

function Internal:new(protocol)
  ---@class OrgLinkHandlerInternal
  local this = Link:new(protocol)
  setmetatable(this, self)
  self.__index = self
  return this
end

---@param target string | nil
---@param disallow_file boolean?
---@return OrgLinkHandlerInternal | OrgLinkHandlerFile | nil
function Internal.parse(target, disallow_file)
  local Headline = require('orgmode.org.hyperlinks.builtin.headline')
  local CustomId = require('orgmode.org.hyperlinks.builtin.custom_id')
  local LineNumber = require('orgmode.org.hyperlinks.builtin.line_number')
  local File = require('orgmode.org.hyperlinks.builtin.file')
  local Plain = require('orgmode.org.hyperlinks.builtin.plain')
  if target == nil then
    return nil
  end
  if target:match('^*') then
    return Headline.parse(target:sub(2))
  end
  if target:match('^#') then
    return CustomId.parse(target:sub(2))
  end
  if target:match('^#d+$') then
    return LineNumber.parse(target)
  end
  if not disallow_file and target:match('^~?/') or target:match('^%.%.?/') then
    return File.parse(target, true)
  end

  return Plain.parse(target)
end

function Internal.get_file_from_context(context)
  context = context or {}
  local file = nil
  if context.id then
    file = (Org.files:find_files_with_property('ID', context.id) or {})[1]
  elseif context.filename then
    file = Org.files:get(context.filename)
  end

  return file or Org.files:get_current_file()
end

function Internal:complete(lead, context)
  context = context or {}
  local Headline = require('orgmode.org.hyperlinks.builtin.headline')
  local CustomId = require('orgmode.org.hyperlinks.builtin.custom_id')
  local LineNumber = require('orgmode.org.hyperlinks.builtin.line_number')
  local File = require('orgmode.org.hyperlinks.builtin.file')
  local Plain = require('orgmode.org.hyperlinks.builtin.plain')

  if lead:match('^*') then
    return Headline:complete(lead:sub(2), context)
  end
  if lead:match('^#') then
    return CustomId:complete(lead:sub(2), context)
  end
  if lead:match('^#d+$') then
    return LineNumber:complete(lead, context)
  end
  if not context.only_internal and lead:match('^~?/') or lead:match('^%.%.?/') then
    return File:complete(lead, vim.tbl_extend('force', context, { skip_prefix = true }))
  end

  return Plain:complete(lead, context)
end

return Internal

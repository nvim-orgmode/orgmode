local utils = require('orgmode.utils')
local Link = require('orgmode.org.hyperlinks.link')

---@class OrgLinkInternal:OrgLink
local Internal = Link:new()

function Internal:new(protocol)
  ---@class OrgLinkInternal
  local this = Link:new(protocol)
  setmetatable(this, self)
  self.__index = self
  return this
end

---@param target string | nil
---@param disallow_file boolean?
---@return OrgLinkInternal | OrgLinkFile | nil
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
    return File.parse(target)
  end

  return Plain.parse(target)
end

---@param headlines OrgHeadline[]
function Internal.goto_oneof(headlines)
  if #headlines == 0 then
    return
  end

  local headline = headlines[1]
  if #headlines > 1 then
    local longest_headline = utils.reduce(headlines, function(acc, h)
      return math.max(acc, h:get_headline_line_content():len())
    end, 0)
    local options = {}
    for i, h in ipairs(headlines) do
      table.insert(
        options,
        string.format(
          '%' .. math.ceil(math.log(longest_headline, 10)) .. 'd) %-' .. longest_headline .. 's (%s)',
          i,
          h:get_headline_line_content(),
          h.file.filename
        )
      )
    end
    vim.cmd([[echo "Multiple targets found. Select target:"]])
    local choice = vim.fn.inputlist(options)
    if choice < 1 or choice > #headlines then
      return
    end
    headline = headlines[choice]
  end

  return utils.goto_headline(headline)
end

function Internal:autocompletions(lead)
  local Headline = require('orgmode.org.hyperlinks.builtin.headline')
  local CustomId = require('orgmode.org.hyperlinks.builtin.custom_id')
  local LineNumber = require('orgmode.org.hyperlinks.builtin.line_number')
  local File = require('orgmode.org.hyperlinks.builtin.file')
  local Plain = require('orgmode.org.hyperlinks.builtin.plain')

  if lead:match('^*') then
    return Headline:autocompletions(lead:sub(2))
  end
  if lead:match('^#') then
    return CustomId:autocompletions(lead:sub(2))
  end
  if lead:match('^#d+$') then
    return LineNumber:autocompletions(lead)
  end
  if lead:match('^~?/') or lead:match('^%.%.?/') then
    return File:autocompletions(lead)
  end

  return Plain:autocompletions(lead)
end

return Internal

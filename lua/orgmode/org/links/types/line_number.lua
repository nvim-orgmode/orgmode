local utils = require('orgmode.utils')
local OrgLinkUrl = require('orgmode.org.links.url')

---@class OrgLinkLineNumber:OrgLinkType
---@field private files OrgFiles
local OrgLinkLineNumber = {}
OrgLinkLineNumber.__index = OrgLinkLineNumber

---@param opts { files: OrgFiles }
function OrgLinkLineNumber:new(opts)
  local this = setmetatable({
    files = opts.files,
  }, OrgLinkLineNumber)
  return this
end

---@return string
function OrgLinkLineNumber:get_name()
  return 'line_number'
end

---@param link string
---@return boolean
function OrgLinkLineNumber:follow(link)
  local opts = self:_parse(link)
  if not opts then
    return false
  end

  local cmd = string.format('edit +%s %s', opts.line_number, opts.file_path)
  vim.cmd(cmd)
  vim.cmd([[normal! zv]])
  return true
end

---@return string[]
function OrgLinkLineNumber:autocomplete(_)
  return {}
end

---@private
---@param link string
---@return { line_number: number, file_path: string  } | nil
function OrgLinkLineNumber:_parse(link)
  local link_url = OrgLinkUrl:new(link)
  local target = link_url:get_target()
  local path = link_url:get_path()
  local file_path = link_url:get_file_path()
  local line_number = target and target:match('^%d+$')
  local protocol = link_url:get_protocol()

  if (protocol == 'file' or file_path) and line_number then
    return {
      line_number = tonumber(line_number),
      file_path = file_path and file_path ~= '' and file_path or utils.current_file_path(),
    }
  end

  return nil
end

return OrgLinkLineNumber

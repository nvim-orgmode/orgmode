local fs = require('orgmode.utils.fs')
local link_utils = require('orgmode.org.links.utils')

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

function OrgLinkLineNumber:get_name()
  return 'headline'
end

---@param link string
---@return boolean
function OrgLinkLineNumber:follow(link)
  local opts = self:_parse(link)
  if not opts then
    return false
  end

  local cmd = string.format('edit +%s %s', opts.line_number, fs.get_real_path(opts.file.filename))
  vim.cmd(cmd)
  vim.cmd([[normal! zv]])
  return true
end

---@private
---@param link string
---@return { line_number: number, file: OrgFile  } | nil
function OrgLinkLineNumber:_parse(link)
  local parts = vim.split(link, '::', { plain = true })
  if #parts < 2 then
    return nil
  end

  local line_number = parts[#parts]:match('^%d+$')

  if line_number then
    return {
      line_number = tonumber(line_number),
      file = self.files:get_current_file(),
    }
  end

  -- TODO: Add support for file format
  return nil
end

return OrgLinkLineNumber

local fs = require('orgmode.utils.fs')

---@class OrgLinkUrl
---@field url string
---@field protocol string | nil
---@field path string
---@field target string | nil
local OrgLinkUrl = {}
OrgLinkUrl.__index = OrgLinkUrl

---@param url string
function OrgLinkUrl:new(url)
  local this = setmetatable({
    url = url,
  }, OrgLinkUrl)
  this:_parse()
  return this
end

---@return string | nil
function OrgLinkUrl:get_file_path()
  if self.protocol == 'file' then
    return self:_get_real_path()
  end

  local first_char = self.path:sub(1, 1)

  if first_char == '/' then
    return self:_get_real_path()
  end

  if
    (first_char == '.' and (self.path:sub(1, 3) == '../' or self.path:sub(1, 2) == './'))
    or (first_char == '~' and self.path:sub(2, 2) == '/')
  then
    return self:_get_real_path()
  end

  return nil
end

---@return string
function OrgLinkUrl:get_path_with_protocol()
  if not self.protocol or self.protocol == '' then
    return self.path
  end

  return ('%s:%s'):format(self.protocol, self.path)
end

---@return string
function OrgLinkUrl:get_target()
  return self.target
end

---@return string
function OrgLinkUrl:get_path()
  return self.path
end

---@return string
function OrgLinkUrl:get_protocol()
  return self.protocol
end

---@return boolean
function OrgLinkUrl:is_id()
  return self.protocol == 'id'
end

---@return string | nil
function OrgLinkUrl:get_id()
  if not self:is_id() then
    return nil
  end
  return self.path
end

---@private
---@return string
function OrgLinkUrl:_get_real_path()
  return fs.get_real_path(self.path) or self.path
end

---@return string
function OrgLinkUrl:to_string()
  return self.url
end

---@private
function OrgLinkUrl:_parse()
  self.protocol = self.url:match('^(%w+):')
  self.path = self.protocol and self.url:sub(#self.protocol + 2) or self.url

  self:_parse_target()
end

---@private
function OrgLinkUrl:_parse_target()
  local path_and_target = vim.split(self.path, '::', { plain = true })
  if #path_and_target < 2 then
    return
  end
  self.path = vim.trim(path_and_target[1])
  self.target = vim.trim(table.concat({ unpack(path_and_target, 2, #path_and_target) }, ''))
end

return OrgLinkUrl

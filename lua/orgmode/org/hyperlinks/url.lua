---@alias OrgUrlPathType 'file' | 'headline' | 'custom-id' | 'id' | 'external-url' | 'plain' | nil
---@alias OrgUrlTargetType 'headline' | 'custom-id' | 'line-number' | 'unknown' | nil

---@class OrgUrl
---@field url string
---@field protocol string
---@field path string
---@field path_type OrgUrlPathType
---@field target { type: OrgUrlTargetType, value: string | number | nil }
local Url = {}
Url.__index = Url

---@param url string
function Url:new(url)
  local this = setmetatable({
    url = url or '',
  }, Url)
  this:_parse()
  return this
end

---@return string
function Url:to_string()
  return self.url
end

---@return string | number | nil
function Url:get_target_value()
  return self.target and self.target.value
end

---@return boolean
function Url:is_headline()
  return self:is_file_headline() or self:is_internal_headline()
end

---@return string | nil
function Url:get_custom_id()
  if self:is_file_custom_id() then
    return tostring(self.target.value)
  end
  if self:is_internal_custom_id() then
    return self.path
  end
  return nil
end

---@return string | nil
function Url:get_headline()
  if self:is_file_headline() then
    return tostring(self.target.value)
  end
  if self:is_internal_headline() then
    return self.path
  end
  return nil
end

---@return boolean
function Url:is_custom_id()
  return self:is_file_custom_id() or self:is_internal_custom_id()
end

function Url:is_id()
  return self.protocol == 'id'
end

---@return string | nil
function Url:get_id()
  if not self:is_id() then
    return nil
  end
  return self.path
end

---@return boolean
function Url:is_file_line_number()
  return self:is_file() and self:get_line_number() and true or false
end

---@return boolean
function Url:is_file_headline()
  return self:is_file() and self.target and self.target.type == 'headline' or false
end

---@return boolean
function Url:is_plain()
  return self.path_type == 'plain'
end

---@return string | nil
function Url:get_plain()
  if self:is_plain() then
    return self.path
  end
  return nil
end

---@return boolean
function Url:is_internal_headline()
  return self.path_type == 'headline'
end

---@return boolean
function Url:is_file_custom_id()
  return self:is_file() and self.target and self.target.type == 'custom-id' or false
end

---@return boolean
function Url:is_internal_custom_id()
  return self.path_type == 'custom-id'
end

---@return string | nil
function Url:get_file()
  if not self:is_file() then
    return nil
  end
  return self.path
end

---@return string | nil
function Url:get_file_with_protocol()
  if not self:is_file() then
    return nil
  end
  if self.protocol and self.protocol ~= '' then
    return table.concat({ self.protocol, self.path }, ':')
  end
  return self.path
end

---@return number | nil
function Url:get_line_number()
  if self.target and self.target.type == 'line-number' then
    return tonumber(self.target.value)
  end
  return nil
end

---@return boolean
function Url:is_file()
  if self.protocol and self.protocol ~= 'file' then
    return false
  end
  return self.path_type == 'file'
end

---@return boolean
function Url:is_file_only()
  return self:is_file() and not self.target
end

---@return boolean
function Url:is_external_url()
  return self:get_external_url() and true or false
end

---@return string | nil
function Url:get_external_url()
  if self.path_type == 'external-url' then
    return self.path
  end
  return nil
end

---@return boolean
function Url:is_supported_protocol()
  if not self.protocol then
    return true
  end
  return self.protocol == 'file' or self.protocol == 'id' or self.protocol:match('https?')
end

---@private
function Url:_parse()
  local path_and_target = vim.split(self.url, '::', { plain = true })

  self:_parse_path_and_protocol(path_and_target[1])
  self:_parse_target(path_and_target[2])
end

---@private
---@param value string
function Url:_parse_path_and_protocol(value)
  local path_and_protocol = vim.split(value, ':', { plain = true })

  if #path_and_protocol >= 2 then
    self.protocol = vim.trim(path_and_protocol[1])
    self.path = vim.trim(table.concat({ unpack(path_and_protocol, 2, #path_and_protocol) }, ''))
  else
    self.path = vim.trim(path_and_protocol[1])
  end

  self:_parse_legacy_line_number()
  self:_parse_path_type()
end

---@private
function Url:_parse_legacy_line_number()
  -- Parse legacy line number syntax
  if self.path:match('%s+%+%d+$') then
    self.target = { type = 'line-number', value = tonumber(self.path:match('%s+%+(%d+)$')) or 0 }
    self.path = self.path:match('^(.-)%s+%+%d+$')
  end
end

---@private
---@param value string
function Url:_parse_target(value)
  local target = value and vim.trim(value) or nil
  if not target or target == '' then
    return
  end
  self.target = { type = 'unknown', value = target }
  if target:find('^%d+$') then
    self.target.type = 'line-number'
    self.target.value = tonumber(target) or 0
  elseif target:find('^*') then
    self.target.type = 'headline'
    self.target.value = target:sub(2)
  elseif target:find('^#') then
    self.target.type = 'custom-id'
    self.target.value = target:sub(2)
  end
end

---@private
---@return OrgUrlPathType
function Url:_parse_path_type()
  local protocol = self.protocol or ''
  if protocol == 'file' or protocol == 'id' then
    self.path_type = protocol
    return
  end

  if protocol:match('https?') then
    self.path_type = 'external-url'
    return
  end

  local first_char = self.path:sub(1, 1)

  if first_char == '/' then
    self.path_type = 'file'
    return
  end

  if first_char == '.' and (self.path:sub(1, 3) == '../' or self.path:sub(1, 2) == './') then
    self.path_type = 'file'
    return
  end

  if first_char == '*' then
    self.path_type = 'headline'
    self.path = self.path:sub(2)
    return
  end

  if first_char == '#' then
    self.path_type = 'custom-id'
    self.path = self.path:sub(2)
    return
  end

  self.path_type = 'plain'
end

return Url

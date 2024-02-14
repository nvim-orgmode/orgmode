local fs = require('orgmode.utils.fs')

---@class OrgUrl
---@field str string
local Url = {}

function Url:init(str)
  self.str = str
end

function Url.new(str)
  local self = setmetatable({}, { __index = Url })
  self:init(str)
  return self
end

---@return boolean
function Url:is_file_line_number()
  return self:get_linenumber() and true
end

---@return boolean
function Url:is_headline()
  return self:is_file_headline() or self:is_internal_headline()
end

---@return boolean
function Url:is_file_headline()
  return self:is_file() and self:get_headline() and true or false
end

---@return boolean
function Url:is_custom_id()
  return (self:is_file_custom_id() or self:is_internal_custom_id()) and true or false
end

---@return boolean
function Url:is_id()
  return self.str:find('^id:') and true or false
end

---@return boolean
function Url:is_file_custom_id()
  return self:is_file() and self:get_custom_id() and true or false
end

---@return boolean
function Url:is_file_anchor()
  return self:get_dedicated_target() and true
end

---@return boolean
function Url:is_org_link()
  return (self:get_dedicated_target() or self:get_custom_id() or self:get_headline()) and true
end

function Url:is_file()
  return self.str:find('^file:') or self.str:find('^%.%./') or self.str:find('^%./') or self.str:find('^/')
end

function Url:is_file_plain()
  return self:is_file() and not self:is_org_link() and not self:is_file_line_number()
end

---@return boolean
function Url:is_http_url()
  return self:get_http_url() and true
end

---@return boolean
function Url:is_internal_headline()
  return self.str:find('^*') and true or false
end

function Url:is_internal_custom_id()
  return self.str:find('^#')
end

function Url:is_dedicated_anchor_or_internal_title()
  return self:get_dedicated_target() ~= nil
end

---@return string | false
function Url:extract_path()
  local url = self
  if url:is_file_headline() or url:is_file_custom_id() then
    return url.str:match('^file:([^:]-)::')
      or url.str:match('^(%.%./[^:]-)::')
      or url.str:match('^(%./[^:]-)::')
      or url.str:match('^(/[^:]-)::')
  elseif url:is_file_line_number() then
    return url.str:match('^file:([^:]-) %+')
      or url.str:match('^(%.%./[^:]-) %+')
      or url.str:match('^(%./[^:]-) %+')
      or url.str:match('^(/[^:]-) %+')
  elseif url:is_file_plain() then
    return url.str:match('^file:([^:]-)$')
      or url.str:match('^(%.%./[^:]-)$')
      or url.str:match('^(%./[^:]-)$')
      or url.str:match('^(/[^:]-)$')
  else
    return false
  end
end

---@return string | false
function Url:get_file_real_path()
  local filepath = self:get_filepath()
  return filepath and fs.get_real_path(filepath)
end

---@return string | false
function Url:get_headline()
  return self.str:match('^file:[^:]+::%*(.-)$')
    or self.str:match('^%.%./[^:]+::%*(.-)$')
    or self.str:match('^%./[^:]+::%*(.-)$')
    or self.str:match('^/[^:]+::%*(.-)$')
    or self.str:match('^%*(.-)$')
end

---@return string | false
function Url:get_custom_id()
  return self.str:match('^file:[^:]+::#(.-)$')
    or self.str:match('^%.%./[^:]+::#(.-)$')
    or self.str:match('^%./[^:]+::#(.-)$')
    or self.str:match('^/[^:]+::#(.-)$')
    or self.str:match('^#(.-)$')
end

function Url:get_id()
  return self.str:match('^id:(%S+)')
end

---@return number | false
function Url:get_linenumber()
  -- official orgmode convention
  return self.str:match('^file:[^:]+::(%d+)$')
    or self.str:match('^%.%./[^:]+::(%d+)$')
    or self.str:match('^%./[^:]+::(%d+)$')
    or self.str:match('^/[^:]+::(%d+)$')
    -- for backwards compatibility
    or self.str:match('^file:[^:]+ %+(%d+)$')
    or self.str:match('^%.%./[^:]+ %+(%d+)$')
    or self.str:match('^%./[^:]+ %+(%d+)$')
    or self.str:match('^/[^:]+ %+(%d+)$')
end

---@return string | false
function Url:get_filepath()
  return
    -- for backwards compatibility
    self.str:match('^file:([^:]+) %+%d+')
      or self.str:match('^(%.%./[^:]+) %+%d+')
      or self.str:match('^(%./[^:]+) %+%d+')
      or self.str:match('^(/[^:]+) %+%d+')
      -- official orgmode convention
      or self.str:match('^file:([^:]+)::')
      or self.str:match('^(%.%./[^:]+)::')
      or self.str:match('^(%./[^:]+)::')
      or self.str:match('^(/[^:]+)::')
      or self.str:match('^file:([^:]+)$')
      or self.str:match('^(%.%./[^:]+)$')
      or self.str:match('^(%./[^:]+)$')
      or self.str:match('^(/[^:]+)$')
      or self.str:match('^(%.%./)$')
      or self.str:match('^(%./)$')
      or self.str:match('^(/)$')
end
--
---@return string
function Url:get_headline_completion()
  return self.str:match('^.+::%*(.*)$') or self.str:match('^%*(.*)$')
end

---@return string
function Url:get_custom_id_completion()
  return self.str:match('^.+::#(.*)$') or self.str:match('^#(.*)$')
end

---@return string | false
function Url:get_dedicated_target()
  return not self:get_filepath()
    and not self:get_linenumber()
    and not self:get_headline()
    and self.str:match('^([%w%s%-%+%=_]+)$')
end

---@return string | false
function Url:get_http_url()
  return self.str:match('^https?://.+$')
end

---@return string | false
function Url:extract_target()
  return self:get_headline() or self:get_custom_id() or self:get_dedicated_target()
end

return Url

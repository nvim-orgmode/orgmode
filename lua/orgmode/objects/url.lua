local utils = require('orgmode.utils')

---@return string | false
local function extract_path(url)
  if url:is_file_headline() or url:is_file_custom_id() then
    return url.str:match('^file:([^:]-)::')
  elseif url:is_file_line_number() then
    return url.str:match('^file:([^:]-) %+')
  elseif url:is_file_plain() then
    return url.str:match('^file:([^:]-)$')
  else
    return false
  end
end

local function substitute_path(path_str)
  if path_str:match('^/') then
    return path_str
  elseif path_str:match('^~/') then
    return path_str:gsub('^~', os.getenv('HOME'))
  elseif path_str:match('^./') then
    local base = vim.fn.fnamemodify(utils.current_file_path(), ':p:h')
    return base .. '/' .. path_str:gsub('^./', '')
  else
    return false
  end
end

---@class Url
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
function Url:is_file_headline()
  return self:get_headline() and true
end

---@return boolean
function Url:is_file_custom_id()
  return self:get_custom_id() and true
end

---@return boolean
function Url:is_file_anchor()
  return self:get_dedicated_target() and true
end

---@return boolean
function Url:is_org_link()
  return (self:get_dedicated_target() or self:get_custom_id() or self:get_headline()) and true
end

function Url:is_file_plain()
  return (self.str:find('^file:') or self.str:find('^./') or self.str:find('^/')) and not self:is_org_link()
end

---@return boolean
function Url:is_http_url()
  return self:get_http_url() and true
end

function Url:is_internal_headline()
  return self.str:find('^*')
end

function Url:is_internal_custom_id()
  return self.str:find('^#')
end

---@return string | false
function Url:get_file_real_path()
  local path = extract_path(self)
  if not path then
    return false
  end
  local substituted = substitute_path(path)
  if not substituted then
    return false
  end
  local real = vim.loop.fs_realpath(substituted)
  return real or false
end

---@return string | false
function Url:get_headline()
  return self.str:match('^file:.+::%*(.+)$') or self.str:match('^./.+::%*(.+)$') or self.str:match('^/.+::%*(.+)$')
end

---@return string | false
function Url:get_custom_id()
  return self.str:match('^file:[^:]+::#(.+)$')
    or self.str:match('^./[^:]+::#(.+)$')
    or self.str:match('^/[^:]+::#(.+)$')
end

function Url:get_dedicated_anchor()
  return not (self:get_headline() or self:get_filepath()) and self.str:match('^file:[^:]+::(.+)$')
    or self.str:match('^./[^:]+::(.+)')
    or self.str:match('^/[^:]+::(.+)')
end

---@return number | false
function Url:get_linenumber()
  -- official orgmode convention
  return self.str:match('^file:[^:]+::(%d-)$')
    or self.str:match('^./[^:]+::(%d-)')
    or self.str:match('^/[^:]+::(%d-)')
    -- for backwards compatibility
    or self.str:match('^file:[^:]+ %+(%d-)')
    or self.str:match('^./[^:]+ %+(%d-)')
    or self.str:match('^/[^:]+ %+(%d-)')
end

---@return string | false
function Url:get_filepath()
  return self.str:match('^file:([^:]+)$')
    or self.str:match('^./([^:])$')
    or self.str:match('^/([^:])$')
    -- official orgmode convention
    or self.str:match('^file:([^:]+)::')
    or self.str:match('^./([^:]+)::')
    or self.str:match('^/([^:]+)::')
    -- for backwards compatibility
    or self.str:match('^file:([^:]+) %+')
    or self.str:match('^./([^:]+) %+')
    or self.str:match('^/([^:]+) %+')
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

return Url

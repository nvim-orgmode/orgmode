local utils = require('orgmode.utils')

---@class OrgLink
---@field new fun(self: OrgLink, protocol?: string): OrgLink
---@field parse fun(input: string): OrgLink | nil
---@field complete fun(self: OrgLink, lead: string): OrgLink[]
---@field resolve fun(self: OrgLink): OrgLink
---@field insert_description fun(self: OrgLink): string | nil
---@field protocol string?
local Link = {}

function Link:new(protocol)
  local this = { protocol = protocol }
  setmetatable(this, self)
  self.__index = self
  return this
end

function Link.parse(input)
  local config = require('orgmode.config')

  -- Finds singular :
  local _, protocol_deliniator = input:find('[a-z0-9-_]*:')

  -- If no protocol is specified, fall back to internal links
  if protocol_deliniator == nil then
    return config.hyperlinks[1].parse(input)
  end

  local protocol = input:sub(1, protocol_deliniator - 1)
  local target = input:sub(protocol_deliniator + 1)
  for prot, handler in pairs(config.hyperlinks) do
    if
      (type(prot) == 'table' and vim.tbl_contains(prot, protocol))
      or (type(prot) == 'string' and prot == protocol)
    then
      return handler.parse(target)
    end
  end
end

function Link:follow()
  utils.echo_warning(string.format('Unsupported link protocol: %q', self.protocol))
end

function Link:resolve()
  return self
end

function Link:insert_description()
  return nil
end

function Link:complete(_)
  return {}
end

return Link

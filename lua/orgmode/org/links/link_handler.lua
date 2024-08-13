local utils = require('orgmode.utils')

---@class OrgLinkHandler
---@field parse fun(input: string): OrgLinkHandler | nil
---@field complete fun(self: OrgLinkHandler, lead: string): OrgLinkHandler[]
---@field resolve fun(self: OrgLinkHandler): OrgLinkHandler
---@field insert_description fun(self: OrgLinkHandler): string | nil
---@field protocol string?
local Link = {}

function Link:new(protocol)
  local this = { protocol = protocol }
  setmetatable(this, self)
  self.__index = self
  return this
end

function Link.parse(input)
  return nil
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

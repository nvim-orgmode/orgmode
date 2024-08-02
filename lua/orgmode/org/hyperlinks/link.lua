local utils = require('orgmode.utils')

---@class OrgLink
---@field new fun(self: OrgLink, protocol?: string): OrgLink
---@field parse fun(input: string): OrgLink | nil
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
  local protocol_deliniator = input:find('[^:\\]:[^:]')

  -- If no protocol is specified, fall back to internal links
  if protocol_deliniator == nil then
    return config.hyperlinks[1].parse(input)
  end

  -- Our find call finds the character _before_ the deliniator due to the neq matcher
  protocol_deliniator = protocol_deliniator + 1

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

---@param lead string
---@return { link: OrgLink, label?: string, desc?: string}[]
function Link:autocompletions(_)
  return {}
end

return Link

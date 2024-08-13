local Internal = require('orgmode.org.hyperlinks.builtin.internal')

---@class OrgLinkHandlerLineNumber:OrgLinkHandlerInternal
local LineNumber = Internal:new()

function LineNumber:new(line_number)
  ---@class OrgLinkHandlerLineNumber
  local this = Internal:new()
  this.line_number = line_number
  setmetatable(this, self)
  self.__index = self
  return this
end

---@param input string
function LineNumber.parse(input)
  return LineNumber:new(tonumber(input))
end

function LineNumber:__tostring()
  return string.format('%d', self.line_number)
end

function LineNumber:follow()
  vim.cmd(('normal! %dGzv'):format(self.line_number))
end

return LineNumber

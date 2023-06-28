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

return Url

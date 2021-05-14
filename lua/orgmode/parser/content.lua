local Content = {}
local Types = require('orgmode.parser.types')

function Content:new(data)
  data = data or {}
  local content = { type = Types.CONTENT }
  content.parent = data.parent.line_nr
  content.level = data.parent.level
  content.line = data.line
  content.line_nr = data.line_nr
  setmetatable(content, self)
  self.__index = self
  return content
end

return Content

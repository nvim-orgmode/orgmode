local Content = {}

function Content:new(data)
  data = data or {}
  data.level = data.parent.level
  data.parent = data.parent
  data.line = data.line
  setmetatable(data, self)
  self.__index = self
  return data
end

return Content

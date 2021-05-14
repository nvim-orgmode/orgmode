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
  content:parse()
  return content
end

function Content:is_keyword()
  return self.type == Types.KEYWORD
end

function Content:parse()
  local keyword = self.line:match('^%s*#%+%S+:')
  if keyword then
    self.type = Types.KEYWORD
    self.keyword = {
      name = keyword:gsub('^%s*#%+', ''):sub(1, -2),
      value = vim.trim(self.line:sub(#keyword + 1))
    }
  end
end

return Content

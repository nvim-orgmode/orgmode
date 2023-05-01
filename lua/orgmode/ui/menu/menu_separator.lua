---@class MenuSeparator
---@field separator? string
---@field length? number
local MenuSeparator = {}

function MenuSeparator:new(data)
  vim.validate({
    separator = { data.separator, 'string', true },
    length = { data.length, 'number', true },
  })

  local opts = {}
  opts.separator = data.separator or '-'
  opts.length = data.length or 80

  setmetatable(opts, self)
  self.__index = self
  return opts
end

return MenuSeparator

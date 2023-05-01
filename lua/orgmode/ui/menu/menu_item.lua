---@class MenuItem
---@field label string
---@field key string
---@field action? function
local MenuItem = {}

function MenuItem:new(data)
  vim.validate({
    label = { data.label, 'string' },
    key = { data.key, 'string' },
    action = { data.action, 'function', true },
  })

  local opts = {}
  opts.label = data.label
  opts.key = data.key
  opts.action = data.action

  setmetatable(opts, self)
  self.__index = self
  return opts
end

return MenuItem

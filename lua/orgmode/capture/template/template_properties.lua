---@class OrgCaptureTemplateProperties
---@field empty_lines { before: integer, after: integer } | number
local TemplateProperties = {}

function TemplateProperties:new(opts)
  opts = opts or {}

  vim.validate({
    empty_lines = { opts.empty_lines, { 'table', 'number' }, true },
  })

  local empty_lines = opts.empty_lines or {}
  if type(empty_lines) == 'number' then
    empty_lines = { before = empty_lines, after = empty_lines }
  else
    empty_lines.before = empty_lines.before or 0
    empty_lines.after = empty_lines.after or 0
  end

  local this = {}
  this.empty_lines = empty_lines

  setmetatable(this, self)
  self.__index = self
  return this
end

return TemplateProperties

---@class TemplateEmptyLines
---@field before integer
---@field after integer

---@class Template
---@field description string
---@field template string|string[]
---@field target string?
---@field headline string?
---@field empty_lines TemplateEmptyLines
local Template = {}

function Template:new(opts)
  opts = opts or {}

  vim.validate({
    description = { opts.description, 'string', true },
    template = { opts.template, 'string', true },
    target = { opts.target, 'string', true },
    headline = { opts.headline, 'string', true },
    empty_lines = { opts.empty_lines, 'table', true },
  })

  local this = {}
  this.description = opts.description
  this.template = opts.template
  this.target = opts.target
  this.headline = opts.headline
  this.empty_lines = vim.tbl_deep_extend('keep', opts.empty_lines or {}, {
    before = 0,
    after = 0,
  })

  setmetatable(this, self)
  self.__index = self
  return this
end

return Template

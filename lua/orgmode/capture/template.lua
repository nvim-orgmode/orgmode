---@class OrgCaptureTemplateEmptyLines
---@field before integer
---@field after integer
local TemplateEmptyLines = {}

function TemplateEmptyLines:new(opts)
  opts = opts or {}

  vim.validate({
    before = { opts.before, 'number', true },
    after = { opts.after, 'number', true },
  })

  local this = {}
  this.before = opts.before or 0
  this.after = opts.after or 0

  setmetatable(this, self)
  self.__index = self
  return this
end

---@class OrgCaptureTemplateProperties
---@field empty_lines OrgCaptureTemplateEmptyLines
local TemplateProperties = {}

function TemplateProperties:new(opts)
  opts = opts or {}

  vim.validate({
    empty_lines = { opts.empty_lines, { 'table', 'number' }, true },
  })

  local empty_lines = opts.empty_lines or {}
  if type(empty_lines) == 'number' then
    empty_lines = { before = empty_lines, after = empty_lines }
  end

  local this = {}
  this.empty_lines = TemplateEmptyLines:new(empty_lines)

  setmetatable(this, self)
  self.__index = self
  return this
end

---@class OrgCaptureTemplate
---@field description string
---@field template string|string[]
---@field target string?
---@field headline string?
---@field properties OrgCaptureTemplateProperties
---@field subtemplates table<string, OrgCaptureTemplate>
local Template = {}

function Template:new(opts)
  opts = opts or {}

  vim.validate({
    description = { opts.description, 'string', true },
    template = { opts.template, { 'string', 'table' }, true },
    target = { opts.target, 'string', true },
    headline = { opts.headline, 'string', true },
    properties = { opts.properties, 'table', true },
    subtemplates = { opts.subtemplates, 'table', true },
  })

  local this = {}
  this.description = opts.description or ''
  this.template = opts.template or ''
  this.target = opts.target
  this.headline = opts.headline
  this.properties = TemplateProperties:new(opts.properties)

  this.subtemplates = {}
  for key, subtemplate in pairs(opts.subtemplates or {}) do
    this.subtemplates[key] = Template:new(subtemplate)
  end

  setmetatable(this, self)
  self.__index = self
  return this
end

return Template

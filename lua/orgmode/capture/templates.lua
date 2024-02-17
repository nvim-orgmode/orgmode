local config = require('orgmode.config')
local Template = require('orgmode.capture.template')

---@see https://orgmode.org/manual/Capture-templates.html

---@class OrgCaptureTemplates
---@field templates table<string, OrgCaptureTemplate>
local Templates = {}

function Templates:new(templates)
  local opts = {}

  vim.validate({
    templates = { templates, 'table', true },
  })

  opts.templates = {}
  for key, template in pairs(templates or config.org_capture_templates) do
    if type(template) == 'table' then
      local tpl = vim.deepcopy(template)
      if not tpl.target then
        tpl.target = config.org_default_notes_file
      end
      opts.templates[key] = Template:new(tpl)
    else
      opts.templates[key] = template
    end
  end

  setmetatable(opts, self)
  self.__index = self
  return opts
end

function Templates:get_list()
  return self.templates
end

return Templates

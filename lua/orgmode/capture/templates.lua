local config = require('orgmode.config')
local Date = require('orgmode.objects.date')
local expansions = {
  ['%t'] = function() return string.format('<%s>', Date.today():to_string()) end,
  ['%T'] = function() return string.format('<%s>', Date.now():to_string()) end,
  ['%u'] = function() return string.format('[%s]', Date.today():to_string()) end,
  ['%U'] = function() return string.format('[%s]', Date.now():to_string()) end,
}

---@see https://orgmode.org/manual/Capture-templates.html

---@class Templates
---@field templates table<string, table>
local Templates = {}

function Templates:new()
  local opts = {}
  opts.templates = vim.tbl_extend('force', {
    t = {
      description = 'Task',
      template = '* TODO %?\n  %u',
      type = 'entry', -- TODO
    }
  }, config.org_agenda_templates)
  setmetatable(opts, self)
  self.__index = self
  return opts
end

function Templates:get_list()
  return self.templates
end

function Templates:compile(template)
  local content = template.template
  if type(content) == 'table' then
    content = table.concat(content, '\n')
  end
  for expansion, compiler in pairs(expansions) do
    content = content:gsub(vim.pesc(expansion), compiler())
  end
  return vim.split(content, '\n', true)
end

function Templates:setup()
  local initial_position = vim.fn.search('%?')
  if initial_position > 0 then
    vim.cmd[[norm!c2l]]
    vim.cmd[[startinsert!]]
  end
end

return Templates

local config = require('orgmode.config')
local Date = require('orgmode.objects.date')
local expansions = {
  ['%%x'] = function()
    return vim.fn.getreg('+')
  end,
  ['%%t'] = function()
    return string.format('<%s>', Date.today():to_string())
  end,
  ['%%T'] = function()
    return string.format('<%s>', Date.now():to_string())
  end,
  ['%%u'] = function()
    return string.format('[%s]', Date.today():to_string())
  end,
  ['%%U'] = function()
    return string.format('[%s]', Date.now():to_string())
  end,
  ['%%a'] = function()
    return string.format('[[file:%s +%s]]', vim.api.nvim_buf_get_name(0), vim.api.nvim_win_get_cursor(0)[1])
  end,
  ['%%%^%{.*%}'] = function(pattern, content)
    local match = string.match(content, '%{(.*)%}')
    if match then
      local content = vim.fn.input(match..": ")
      return content
    else
      return ""
    end
  end,
}

---@see https://orgmode.org/manual/Capture-templates.html

---@class Templates
---@field templates table<string, table>
local Templates = {}

-- TODO Introduce type
function Templates:new()
  local opts = {}
  opts.templates = config.org_agenda_templates
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
  content = self:_compile_dates(content)
  for expansion, compiler in pairs(expansions) do
    content = content:gsub(expansion, compiler(expansion, content))
  end
  return vim.split(content, '\n', true)
end

function Templates:setup()
  local initial_position = vim.fn.search('%?')
  local is_at_end_of_line = vim.fn.search('%?$') > 0
  if initial_position > 0 then
    vim.cmd([[norm!c2l]])
    if is_at_end_of_line then
      vim.cmd([[startinsert!]])
    else
      vim.cmd([[norm!l]])
      vim.cmd([[startinsert]])
    end
  end
end

---@param content string
---@return string
function Templates:_compile_dates(content)
  for exp in content:gmatch('%%<[^>]*>') do
    content = content:gsub(vim.pesc(exp), os.date(exp:sub(3, -2)))
  end
  return content
end

return Templates

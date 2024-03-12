local TemplateProperties = require('orgmode.capture.template.template_properties')
local Date = require('orgmode.objects.date')
local utils = require('orgmode.utils')
local Calendar = require('orgmode.objects.calendar')
local Promise = require('orgmode.utils.promise')

local expansions = {
  ['%f'] = function()
    return vim.fn.expand('%')
  end,
  ['%F'] = function()
    return vim.fn.expand('%:p')
  end,
  ['%n'] = function()
    return os.getenv('USER')
  end,
  ['%x'] = function()
    return vim.fn.getreg('+')
  end,
  ['%t'] = function()
    return string.format('<%s>', Date.today():to_string())
  end,
  ['%T'] = function()
    return string.format('<%s>', Date.now():to_string())
  end,
  ['%u'] = function()
    return string.format('[%s]', Date.today():to_string())
  end,
  ['%U'] = function()
    return string.format('[%s]', Date.now():to_string())
  end,
  ['%a'] = function()
    return string.format('[[file:%s::%s]]', utils.current_file_path(), vim.api.nvim_win_get_cursor(0)[1])
  end,
}

---@class OrgCaptureTemplate
---@field description? string
---@field template? string|string[]
---@field target? string
---@field datetree? OrgCaptureTemplateDatetree
---@field headline? string
---@field regexp? string
---@field properties? OrgCaptureTemplateProperties
---@field subtemplates? table<string, OrgCaptureTemplate>
local Template = {}

---@param opts OrgCaptureTemplate
---@return OrgCaptureTemplate
function Template:new(opts)
  opts = opts or {}

  vim.validate({
    description = { opts.description, 'string', true },
    template = { opts.template, { 'string', 'table' }, true },
    target = { opts.target, 'string', true },
    regexp = { opts.regexp, 'string', true },
    headline = { opts.headline, 'string', true },
    properties = { opts.properties, 'table', true },
    subtemplates = { opts.subtemplates, 'table', true },
    datetree = { opts.datetree, { 'boolean', 'table' }, true },
  })

  local this = {}
  this.description = opts.description or ''
  this.template = opts.template or ''
  this.target = self:_compile(opts.target or '')
  this.headline = opts.headline
  this.properties = TemplateProperties:new(opts.properties)
  this.datetree = opts.datetree
  this.regexp = opts.regexp

  this.subtemplates = {}
  for key, subtemplate in pairs(opts.subtemplates or {}) do
    this.subtemplates[key] = Template:new(subtemplate)
  end

  setmetatable(this, self)
  self.__index = self
  return this
end

function Template:setup()
  local initial_position = vim.fn.search('%?')
  local is_at_end_of_line = vim.fn.search('%?$') > 0
  if initial_position > 0 then
    vim.cmd([[norm!"_c2l]])
    if is_at_end_of_line then
      vim.cmd([[startinsert!]])
    else
      vim.cmd([[norm!l]])
      vim.cmd([[startinsert]])
    end
  end
end

function Template:validate_options()
  self:_validate_regexp()
  if self.datetree then
    if type(self.datetree) == 'table' then
      if self.datetree.tree_type == 'custom' and not self.datetree.tree then
        utils.echo_error('Custom datetree type requires a tree option')
      end
    end
  end
end

function Template:_validate_regexp()
  if self.headline and self.regexp then
    local desc = self.description ~= '' and self.description or self.template
    utils.echo_error(('Cannot use both headline and regexp options in the same capture template "%s"'):format(desc))
  end
end

function Template:_validate_datetree()
  if not self.datetree or self.datetree == true then
    return
  end
  if type(self.datetree) ~= 'table' then
    return utils.echo_error('Datetree option must be a table or a boolean')
  end
  if self.datetree.tree_type then
    local valid_tree_types = { 'day', 'week', 'month', 'custom' }
    if not vim.tbl_contains(valid_tree_types, self.datetree.tree_type) then
      return utils.echo_error(('Invalid tree type "%s"'):format(self.datetree.tree_type))
    end

    if self.datetree.tree_type == 'custom' then
      if not self.datetree.tree or type(self.datetree.tree) ~= 'table' then
        return utils.echo_error('Custom tree type requires a tree option to be a table (array of OrgDatetreeTreeItem)')
      end
      if #self.datetree.tree == 0 then
        return utils.echo_error(
          'Custom tree type requires a tree option to be a non-empty table (array of OrgDatetreeTreeItem)'
        )
      end
    end
  end
end

function Template:compile()
  self:validate_options()
  local content = self.template
  if type(content) == 'table' then
    content = table.concat(content, '\n')
  end
  content = self:_compile(content or '')
  return vim.split(content, '\n', { plain = true })
end

function Template:has_input_prompts()
  return self.datetree and type(self.datetree) == 'table' and self.datetree.time_prompt
end

function Template:prompt_for_inputs()
  if not self:has_input_prompts() then
    return Promise.resolve(true)
  end
  return Calendar.new({ date = Date.now() }):open():next(function(date)
    if date then
      self.datetree.date = date
      return true
    end
    return false
  end)
end

---@return OrgCaptureTemplateDatetreeOpts
function Template:get_datetree_opts()
  ---@diagnostic disable-next-line: param-type-mismatch
  local datetree = vim.deepcopy(self.datetree)
  datetree = (type(datetree) == 'table' and datetree) or {}
  datetree.date = datetree.date or Date.today()
  datetree.tree_type = datetree.tree_type or 'day'
  return datetree
end

---@return string
function Template:get_target()
  return vim.fn.resolve(vim.fn.fnamemodify(self.target, ':p'))
end

---@param lines string[]
---@return string[]
function Template:apply_properties_to_lines(lines)
  local empty_lines = self.properties.empty_lines

  for _ = 1, empty_lines.before do
    table.insert(lines, 1, '')
  end

  for _ = 1, empty_lines.after do
    table.insert(lines, '')
  end

  return lines
end

---@private
---@param content string
---@return string
function Template:_compile(content)
  content = self:_compile_dates(content)
  content = self:_compile_expansions(content)
  content = self:_compile_expressions(content)
  content = self:_compile_prompts(content)
  return content
end

---@param content string
---@return string
function Template:_compile_expansions(content, found_expansions)
  found_expansions = found_expansions or expansions
  for expansion, compiler in pairs(found_expansions) do
    if content:match(vim.pesc(expansion)) then
      content = content:gsub(vim.pesc(expansion), vim.pesc(compiler()))
    end
  end
  return content
end

---@param content string
---@return string
function Template:_compile_dates(content)
  for exp in content:gmatch('%%<[^>]*>') do
    content = content:gsub(vim.pesc(exp), os.date(exp:sub(3, -2)))
  end
  return content
end

---@param content string
---@return string
function Template:_compile_prompts(content)
  for exp in content:gmatch('%%%^%b{}') do
    local details = exp:match('%{(.*)%}')
    local parts = vim.split(details, '|')
    local title, default = parts[1], parts[2]
    local response
    if #parts > 2 then
      local completion_items = vim.list_slice(parts, 3, #parts)
      local prompt = string.format('%s [%s]: ', title, default)
      response = vim.fn.OrgmodeInput(prompt, '', function(arg_lead)
        return vim.tbl_filter(function(v)
          return v:match('^' .. vim.pesc(arg_lead))
        end, completion_items)
      end)
    else
      local prompt = default and string.format('%s [%s]:', title, default) or title .. ': '
      response = vim.trim(vim.fn.input({
        prompt = prompt,
        cancelreturn = default or '',
      }))
    end
    if #response == 0 and default then
      response = default
    end
    content = content:gsub(vim.pesc(exp), response)
  end
  return content
end

function Template:_compile_expressions(content)
  for exp in content:gmatch('%%%b()') do
    local snippet = exp:match('%((.*)%)')
    local func = load(snippet)
    ---@diagnostic disable-next-line: param-type-mismatch
    local ok, response = pcall(func)
    if ok then
      content = content:gsub(vim.pesc(exp), response)
    end
  end
  return content
end

return Template

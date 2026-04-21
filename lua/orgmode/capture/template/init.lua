local TemplateProperties = require('orgmode.capture.template.template_properties')
local Date = require('orgmode.objects.date')
local utils = require('orgmode.utils')
local Calendar = require('orgmode.objects.calendar')
local Promise = require('orgmode.utils.promise')
local Input = require('orgmode.ui.input')

---@description For `%^g` expansion in capture templates: gets all tags in the targeted file.
---@param template? table
---@return string[]
local function get_target_tags(template)
  local files = template and template.files
  if not files or not template or template.target == '' then
    return {}
  end

  local ok, file = pcall(function()
    return files:get(template:get_target())
  end)

  if not ok or not file then
    return {}
  end

  return file:get_tags()
end

---@description For `%^G` expansion in capture templates: gets all tags in all agenda files.
---@param template? table
---@return string[]
local function get_all_tags(template)
  local files = template and template.files
  if not files then
    return {}
  end
  return files:get_tags()
end

---@param tags_source string[]
---@return OrgPromise<string>
local function prompt_tags(tags_source)
  local completion = function(arg_lead)
    return utils.prompt_autocomplete(arg_lead, tags_source, { ':' })
  end
  return Input.open('Tags: ', '', completion):next(function(input)
    if input == nil then
      return nil
    end
    if input == '' then
      return ''
    end

    local tags = utils.parse_tags_string(input)
    return utils.tags_to_string(tags)
  end)
end

local expansions = {
  ['%%f'] = function()
    return vim.fn.expand('%')
  end,
  ['%%F'] = function()
    return vim.fn.expand('%:p')
  end,
  ['%%n'] = function()
    if vim.fn.has('win32') == 1 then
      return os.getenv('USERNAME')
    end
    return os.getenv('USER')
  end,
  ['%%x'] = function()
    return vim.fn.getreg('+')
  end,
  ['%%t'] = function()
    return string.format('<%s>', Date.today():to_string())
  end,
  ['%%%^t'] = function()
    return Calendar.new({ date = Date.today() }):open():next(function(date)
      return date and date:to_wrapped_string(true) or nil
    end)
  end,
  ['%%%^%{([^%}]*)%}t'] = function(title)
    return Calendar.new({ date = Date.today(), title = title }):open():next(function(date)
      return date and date:to_wrapped_string(true) or nil
    end)
  end,
  ['%%T'] = function()
    return Date.now():to_wrapped_string(true)
  end,
  ['%%%^T'] = function()
    return Calendar.new({ date = Date.now() }):open():next(function(date)
      return date and date:to_wrapped_string(true) or nil
    end)
  end,
  ['%%%^%{([^%}]*)%}T'] = function(title)
    return Calendar.new({ date = Date.now(), title = title }):open():next(function(date)
      return date and date:to_wrapped_string(true) or nil
    end)
  end,
  ['%%u'] = function()
    return Date.today():to_wrapped_string(false)
  end,
  ['%%%^u'] = function()
    return Calendar.new({ date = Date.today() }):open():next(function(date)
      return date and date:to_wrapped_string(false) or nil
    end)
  end,
  ['%%%^%{([^%}]*)%}u'] = function(title)
    return Calendar.new({ date = Date.today(), title = title }):open():next(function(date)
      return date and date:to_wrapped_string(false) or nil
    end)
  end,
  ['%%U'] = function()
    return Date.now():to_wrapped_string(false)
  end,
  ['%%%^U'] = function()
    return Calendar.new({ date = Date.now() }):open():next(function(date)
      return date and date:to_wrapped_string(false) or nil
    end)
  end,
  ['%%%^%{([^%}]*)%}U'] = function(title)
    return Calendar.new({ date = Date.now(), title = title }):open():next(function(date)
      return date and date:to_wrapped_string(false) or nil
    end)
  end,
  ['%%%^g'] = function(_, template)
    return prompt_tags(get_target_tags(template))
  end,
  ['%%%^G'] = function(_, template)
    return prompt_tags(get_all_tags(template))
  end,
  ['%%a'] = function()
    return string.format('[[file:%s::%s]]', utils.current_file_path(), vim.api.nvim_win_get_cursor(0)[1])
  end,
}

---@class OrgCaptureTemplateOpts
---@field description? string
---@field template? string|string[]
---@field target? string
---@field datetree? OrgCaptureTemplateDatetree
---@field headline? string|fun():string
---@field regexp? string
---@field properties? OrgCaptureTemplateProperties
---@field subtemplates? table<string, OrgCaptureTemplate>
---@field whole_file? boolean

---@class OrgCaptureTemplate:OrgCaptureTemplateOpts
---@field files? OrgFiles
---@field private _compile_hooks? (fun(content:string, content_type: 'target' | 'content'):string | nil)[]
local Template = {}

---@param opts OrgCaptureTemplateOpts
---@return OrgCaptureTemplate
function Template:new(opts)
  opts = opts or {}

  vim.validate('description', opts.description, 'string', true)
  vim.validate('template', opts.template, { 'string', 'table' }, true)
  vim.validate('target', opts.target, 'string', true)
  vim.validate('regexp', opts.regexp, 'string', true)
  vim.validate('headline', opts.headline, { 'string', 'function' }, true)
  vim.validate('properties', opts.properties, 'table', true)
  vim.validate('subtemplates', opts.subtemplates, 'table', true)
  vim.validate('datetree', opts.datetree, { 'boolean', 'table' }, true)
  vim.validate('whole_file', opts.whole_file, 'boolean', true)

  local this = {}
  this.description = opts.description or ''
  this.template = opts.template or ''
  this.target = opts.target or ''
  this.headline = opts.headline
  this.properties = TemplateProperties:new(opts.properties)
  this.datetree = opts.datetree
  this.regexp = opts.regexp
  this.whole_file = opts.whole_file

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

function Template:on_compile(hook)
  self._compile_hooks = self._compile_hooks or {}
  table.insert(self._compile_hooks, hook)
  return self
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
  return self
    :_compile(self.target, 'target')
    :next(function(target)
      if not target then
        return nil
      end
      self.target = target
      return self:_compile(content or '', 'content')
    end)
    :next(function(compiled_content)
      if not compiled_content then
        return nil
      end
      return vim.split(compiled_content, '\n', { plain = true })
    end)
end

---@return OrgCaptureTemplateDatetreeOpts
function Template:get_datetree_opts()
  ---@diagnostic disable-next-line: param-type-mismatch
  local datetree = vim.deepcopy(self.datetree)
  datetree = (type(datetree) == 'table' and datetree) or {}
  datetree.date = datetree.date or Date.now()
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
---@param content_type 'target' | 'content'
---@return OrgPromise<string | nil>
function Template:_compile(content, content_type)
  content = self:_compile_dates(content)
  if self._compile_hooks then
    for _, hook in ipairs(self._compile_hooks) do
      content = hook(content, content_type) --[[@as string]]
      if not content then
        return Promise.resolve(nil)
      end
    end
  end
  return self:_compile_datetree(content, content_type):next(function(compiled_content)
    if not compiled_content then
      return nil
    end
    return self:_compile_expansions(compiled_content):next(function(cnt)
      if not cnt then
        return nil
      end
      cnt = self:_compile_expressions(cnt)
      return self:_compile_prompts(cnt)
    end)
  end)
end

---@param content string
---@param content_type 'target' | 'content'
---@return OrgPromise<string | nil>
function Template:_compile_datetree(content, content_type)
  if
    not self.datetree
    or type(self.datetree) ~= 'table'
    or not self.datetree.time_prompt
    or content_type ~= 'target'
  then
    return Promise.resolve(content)
  end

  return Calendar.new({ date = Date.now(), title = 'Select datetree date' }):open():next(function(date)
    if date then
      self.datetree.date = date
      return content
    end
    return nil
  end)
end

---@param content string
---@return OrgPromise<string | nil>
function Template:_compile_expansions(content)
  local compiled_expansions = {}
  local proceed = true
  for exp in content:gmatch('%%([^%%]*)') do
    for expansion, compiler in pairs(expansions) do
      local match = ('%' .. exp):match(expansion)
      if match then
        table.insert(compiled_expansions, function()
          return Promise.resolve(compiler(match, self)):next(function(replacement)
            if not proceed or not replacement then
              return Promise.reject('canceled')
            end
            content = content:gsub(expansion, vim.pesc(replacement))
            return content
          end)
        end)
      end
    end
  end

  if #compiled_expansions == 0 then
    return Promise.resolve(content)
  end

  local result = Promise.resolve()
  for _, value in ipairs(compiled_expansions) do
    result = result:next(function()
      return value()
    end)
  end

  return result
    :next(function()
      if not proceed then
        return nil
      end
      return content
    end)
    :catch(function(err)
      if err == 'canceled' then
        return
      end
      error(err)
    end)
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
---@return OrgPromise<string>
function Template:_compile_prompts(content)
  local prepared_inputs = {}
  -- Match %^{...} with optional g/G suffix for tag prompts
  for exp in content:gmatch('%%%^%b{}[gG]?') do
    local details = exp:match('%{(.*)%}')
    local parts = vim.split(details, '|')
    local title, default = parts[1], parts[2]

    -- Check if this is a tag prompt (ends with g or G)
    local is_tag_prompt = exp:sub(-1, -1) == 'g' or exp:sub(-1, -1) == 'G'

    local original_exp = exp
    -- If it's a tag prompt, remove the g/G from the expression for replacement
    if is_tag_prompt then
      exp = exp:sub(1, -2) -- Remove just the g/G, keep the closing brace
    end

    local input = {
      fallback_value = default,
      exp = exp,
      original_exp = original_exp, -- Keep the original (with g/G) for replacement
      is_tag_prompt = is_tag_prompt,
    }

    if #parts > 2 then
      input.prompt = string.format('%s [%s]: ', title, default)
      input.completion = function()
        local completion_items = vim.list_slice(parts, 3, #parts)
        return function(arg_lead)
          return vim.tbl_filter(function(v)
            return v:match('^' .. vim.pesc(arg_lead))
          end, completion_items)
        end
      end
    else
      input.prompt = default and string.format('%s [%s]:', title, default) or title .. ': '
    end
    table.insert(prepared_inputs, input)
  end

  if #prepared_inputs == 0 then
    return Promise.resolve(content)
  end

  return Promise.mapSeries(function(prepared_input)
    return Input.open(prepared_input.prompt, '', prepared_input.completion and prepared_input.completion() or nil)
      :next(function(response)
        if not response or #response == 0 then
          response = prepared_input.fallback_value
        end

        -- Handle tag prompts specially - format with colons
        if prepared_input.is_tag_prompt and response and response ~= '' then
          response = utils.tags_to_string(utils.parse_tags_string(response))
        end

        -- For tag prompts, we need to search for the original expression (with g/G)
        -- but use the response which is already formatted (with :tags:)
        -- Don't escape for tag prompts since we need the % to match literally
        if prepared_input.is_tag_prompt then
          -- Manually escape % for tag prompts (other chars dont need escaping for literal match)
          content = content:gsub(prepared_input.original_exp:gsub('%%', '%%%%'), response)
        else
          content = content:gsub(vim.pesc(prepared_input.original_exp), response)
        end
      end)
  end, prepared_inputs):next(function()
    return content
  end)
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

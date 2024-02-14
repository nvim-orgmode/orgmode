local utils = require('orgmode.utils')
local config = require('orgmode.config')
local Templates = require('orgmode.capture.templates')
local Template = require('orgmode.capture.template')
local ClosingNote = require('orgmode.capture.closing_note')
local Menu = require('orgmode.ui.menu')
local Range = require('orgmode.files.elements.range')

---@class OrgCaptureOpts
---@field lines string[]
---@field range OrgRange?
---@field file string?
---@field template OrgCaptureTemplate?
---@field headline string?
---@field item OrgHeadline?
---@field message string?

---@class OrgCapture
---@field templates OrgCaptureTemplates
---@field closing_note OrgClosingNote
---@field files OrgFiles
local Capture = {}

---@param opts { files: OrgFiles }
function Capture:new(opts)
  opts = opts or {}
  local data = {}
  data.files = opts.files
  data.templates = Templates:new()
  data.closing_note = ClosingNote:new()
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param base_key string
---@param templates table<string, OrgCaptureTemplate>
function Capture:_get_subtemplates(base_key, templates)
  local subtemplates = {}
  for key, template in pairs(templates) do
    if string.len(key) > 1 and string.sub(key, 1, 1) == base_key then
      subtemplates[string.sub(key, 2, string.len(key))] = template
    end
  end
  return subtemplates
end

---@param templates table<string, OrgCaptureTemplate>
function Capture:_create_menu_items(templates)
  local menu_items = {}
  for key, template in pairs(templates) do
    if string.len(key) == 1 then
      local item = {
        key = key,
      }
      if type(template) == 'string' then
        item.label = template .. '...'
        item.action = function()
          self:_create_prompt(self:_get_subtemplates(key, templates))
        end
      elseif vim.tbl_count(template.subtemplates) > 0 then
        item.label = template.description .. '...'
        item.action = function()
          self:_create_prompt(template.subtemplates)
        end
      else
        item.label = template.description
        item.action = function()
          return self:open_template(template)
        end
      end
      table.insert(menu_items, item)
    end
  end
  return menu_items
end

---@param templates table<string, OrgCaptureTemplate>
function Capture:_create_prompt(templates)
  local menu = Menu:new({
    title = 'Select a capture template',
    items = self:_create_menu_items(templates),
    prompt = 'Template key',
  })
  menu:add_separator()
  menu:add_option({ label = 'Quit', key = 'q' })
  menu:add_separator({ icon = ' ', length = 1 })
  return menu:open()
end

function Capture:prompt()
  self:_create_prompt(self.templates:get_list())
end

---@param template table
function Capture:open_template(template)
  local content = self.templates:compile(template)
  local on_close = function()
    require('orgmode').action('capture.refile', true)
  end
  self._close_tmp = utils.open_tmp_org_window(16, config.win_split_mode, config.win_border, on_close)
  vim.api.nvim_buf_set_lines(0, 0, -1, true, content)
  self.templates:setup()

  vim.b.org_template = template
  vim.b.org_capture = true
  config:setup_mappings('capture')
end

---@param shortcut string
function Capture:open_template_by_shortcut(shortcut)
  local template = self.templates:get_list()[shortcut]
  if not template then
    return utils.echo_error('No capture template with shortcut ' .. shortcut)
  end
  return self:open_template(template)
end

---Triggered when refiling from capture buffer
---@param confirm? boolean
function Capture:refile(confirm)
  local is_modified = vim.bo.modified
  local opts = self:_get_refile_vars()
  if not opts.file then
    return
  end
  if confirm and is_modified then
    local choice = vim.fn.confirm(string.format('Do you want to refile this to %s?', opts.file), '&Yes\n&No')
    vim.cmd([[redraw!]])
    if choice ~= 1 then
      return utils.echo_info('Canceled.')
    end
  end
  vim.defer_fn(function()
    self:_refile_to(opts)

    if not confirm then
      self:kill()
    end
  end, 0)
end

---Triggered when refiling to destination from capture buffer
function Capture:refile_to_destination()
  local opts = self:_get_refile_vars()
  if not opts.file then
    return
  end
  self:_refile_content_with_fallback(opts)
  self:kill()
end

---@private
---@return OrgCaptureOpts
function Capture:_get_refile_vars()
  local template = vim.b.org_template or {}
  local target = self.templates:compile_target(template.target or config.org_default_notes_file)
  local file = vim.fn.resolve(vim.fn.fnamemodify(target, ':p'))

  if vim.fn.filereadable(file) == 0 then
    local choice = vim.fn.confirm(('Refile destination %s does not exist. Create now?'):format(file), '&Yes\n&No')
    if choice ~= 1 then
      utils.echo_error('Cannot proceed without a valid refile destination')
      return {}
    end
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':h'), 'p')
    vim.fn.writefile({}, file)
  end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  local org_file = self.files:get_current_file()
  local item = nil
  if org_file then
    item = org_file:get_headlines()[1]
  end

  return {
    file = file,
    lines = lines,
    item = item,
    template = template,
    headline = template.headline,
  }
end

---Triggered from org file when we want to refile headline
function Capture:refile_headline_to_destination()
  local item = self.files:get_closest_headline()
  local lines = item:get_lines()
  return self:_refile_content_with_fallback({
    lines = lines,
    item = item,
    template = Template:new(),
  })
end

---@param opts OrgCaptureOpts
---@return boolean
function Capture:refile_file_headline_to_archive(opts)
  opts.message = string.format('Archived to %s', opts.file)
  return self:_refile_to(opts)
end

---@private
---@param opts OrgCaptureOpts
---@return boolean
function Capture:_refile_content_with_fallback(opts)
  local default_file = opts.file and opts.file ~= '' and vim.fn.fnamemodify(opts.file, ':p') or nil

  local valid_destinations = {}
  for _, file in ipairs(self.files:filenames()) do
    valid_destinations[vim.fn.fnamemodify(file, ':t')] = file
  end

  local destination = vim.fn.OrgmodeInput('Enter destination: ', '', function(arg_lead)
    return self:autocomplete_refile(arg_lead)
  end)
  destination = vim.split(destination, '/', { plain = true })

  if not valid_destinations[destination[1]] then
    if not default_file then -- we know that this comes from org_refile and not org_capture_refile
      utils.echo_error(
        "'" .. destination[1] .. "' is not a file specified in the 'org_agenda_files' setting. Refiling cancelled."
      )
      return false
    end
    opts.file = default_file
    return self:_refile_to(opts)
  end

  opts.file = valid_destinations[destination[1]]
  opts.headline = table.concat({ unpack(destination, 2) }, '/')
  return self:_refile_to(opts)
end

---@param item OrgHeadline
---@param target_level integer
---@param is_same_file boolean
function Capture:_adapt_headline_level(item, target_level, is_same_file)
  -- Refiling in same file just moves the lines from one position
  -- to another,so we need to apply demote instantly
  local level = item:get_level()
  if target_level == 0 then
    return item:promote(level - 1, true, not is_same_file)
  end
  if level <= target_level then
    return item:demote(target_level - level + 1, true, not is_same_file)
  end
  return item:promote(level - target_level - 1, true, not is_same_file)
end

---@param opts OrgCaptureOpts
local function add_empty_lines(opts)
  local empty_lines = opts.template.properties.empty_lines

  for _ = 1, empty_lines.before do
    table.insert(opts.lines, 1, '')
  end

  for _ = 1, empty_lines.after do
    table.insert(opts.lines, '')
  end
end

---@param opts OrgCaptureOpts
local function apply_properties(opts)
  if opts.template then
    add_empty_lines(opts)
  end
end

local function remove_buffer_empty_lines(opts)
  local line_count = vim.api.nvim_buf_line_count(0)
  local range = opts.range

  local end_line = range.end_line
  if end_line < 0 then
    end_line = end_line + line_count + 1
  end

  local start_line = end_line - 1

  local is_line_empty = function(row)
    local line = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
    line = vim.trim(line)
    return #line == 0
  end

  while start_line >= 0 and is_line_empty(start_line) do
    start_line = start_line - 1
  end
  start_line = start_line + 1

  while end_line < line_count and is_line_empty(end_line) do
    end_line = end_line + 1
  end

  range.start_line = start_line
  range.end_line = end_line
end

--- Checks, if we refile a heading within one file or from one file to another.
---@param opts OrgCaptureOpts
---@return boolean
local function check_refile_source(opts)
  local source_file = opts.item and opts.item.file.filename or utils.current_file_path()
  local target_file = opts.file
  return source_file == target_file
end

---@private
---@param opts OrgCaptureOpts
---@return boolean
function Capture:_refile_to(opts)
  if not opts.file then
    return false
  end

  local has_headline = opts.headline and opts.headline ~= ''
  local destination_file = self.files:get(opts.file)
  local target_level = 0
  local target_line = -1
  local should_adapt_headline = has_headline or (opts.item ~= nil and opts.item:get_level() > 1)
  if has_headline and destination_file then
    local headline = destination_file:find_headline_by_title(opts.headline)
    if not headline then
      utils.echo_error("headline '" .. opts.headline .. "' does not exist in '" .. opts.file .. "'. Aborted refiling.")
      return false
    end
    target_level = headline:get_level()
    target_line = headline:get_range().end_line
  end

  local item = opts.item
  local is_same_file = check_refile_source(opts)
  if item and should_adapt_headline then
    -- Refiling in same file just moves the lines from one position
    -- to another,so we need to apply demote instantly
    opts.lines = self:_adapt_headline_level(item, target_level, is_same_file)
  end

  opts.range = Range.from_line(target_line)

  apply_properties(opts)

  if is_same_file and item then
    local target = opts.range.end_line
    local view = vim.fn.winsaveview() or {}
    local item_range = item:get_range()
    vim.cmd(string.format('silent! %d,%d move %s', item_range.start_line, item_range.end_line, target))
    vim.fn.winrestview(view)

    utils.echo_info(opts.message or string.format('Wrote %s', opts.file))
    return true
  end

  local edit_file = utils.edit_file(opts.file)

  if not is_same_file then
    edit_file.open()
  end

  remove_buffer_empty_lines(opts)

  ---@type OrgRange
  local range = opts.range
  vim.api.nvim_buf_set_lines(0, range.start_line, range.end_line, false, opts.lines)

  if not is_same_file then
    edit_file.close()
  end

  if item and item.file.filename == utils.current_file_path() then
    local item_range = item:get_range()
    vim.api.nvim_buf_set_lines(0, item_range.start_line - 1, item_range.end_line, false, {})
  end

  utils.echo_info(opts.message or string.format('Wrote %s', opts.file))
  return true
end

---@param arg_lead string
---@return string[]
function Capture:autocomplete_refile(arg_lead)
  local valid_filenames = {}
  for _, filename in ipairs(self.files:filenames()) do
    valid_filenames[vim.fn.fnamemodify(filename, ':t') .. '/'] = filename
  end

  if not arg_lead then
    return vim.tbl_keys(valid_filenames)
  end
  local parts = vim.split(arg_lead, '/', { plain = true })

  local selected_file = valid_filenames[parts[1] .. '/']

  if not selected_file then
    return vim.tbl_filter(function(file)
      return file:match('^' .. vim.pesc(parts[1]))
    end, vim.tbl_keys(valid_filenames))
  end

  local agenda_file = self.files:get(selected_file)
  if not agenda_file then
    return {}
  end

  local headlines = agenda_file:get_opened_unfinished_headlines()
  local result = vim.tbl_map(function(headline)
    return string.format('%s/%s', vim.fn.fnamemodify(headline.file.filename, ':t'), headline:get_title())
  end, headlines)

  return vim.tbl_filter(function(item)
    return item:match(string.format('^%s', vim.pesc(arg_lead)))
  end, result)
end

function Capture:kill()
  if self._close_tmp then
    self._close_tmp()
    self._close_tmp = nil
  end
end

return Capture

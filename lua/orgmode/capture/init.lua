local utils = require('orgmode.utils')
local fs = require('orgmode.utils.fs')
local config = require('orgmode.config')
local Templates = require('orgmode.capture.templates')
local Template = require('orgmode.capture.template')
local Menu = require('orgmode.ui.menu')
local Range = require('orgmode.files.elements.range')
local CaptureWindow = require('orgmode.capture.window')
local Date = require('orgmode.objects.date')
local Datetree = require('orgmode.capture.template.datetree')

---@alias OrgOnCaptureClose fun(capture:OrgCapture, opts:OrgProcessCaptureOpts)
---@alias OrgOnCaptureCancel fun(capture:OrgCapture)

---@class OrgCapture
---@field templates OrgCaptureTemplates
---@field closing_note OrgCaptureWindow
---@field files OrgFiles
---@field on_pre_refile OrgOnCaptureClose
---@field on_post_refile OrgOnCaptureClose
---@field on_cancel_refile OrgOnCaptureCancel
---@field _window OrgCaptureWindow
local Capture = {}
Capture.__index = Capture

---@param opts { files: OrgFiles, templates?: OrgCaptureTemplates, on_pre_refile?: OrgOnCaptureClose, on_post_refile?: OrgOnCaptureClose, on_cancel_refile?: OrgOnCaptureCancel }
function Capture:new(opts)
  local this = setmetatable({}, self)
  this.files = opts.files
  this.on_pre_refile = opts.on_pre_refile
  this.on_post_refile = opts.on_post_refile
  this.on_cancel_refile = opts.on_cancel_refile
  this.templates = opts.templates or Templates:new()
  this.closing_note = this:_setup_closing_note()
  return this
end

function Capture:prompt()
  self:_create_prompt(self.templates:get_list())
end

---@private
function Capture:setup_mappings()
  local maps = config:get_mappings('capture', vim.api.nvim_get_current_buf())
  if not maps then
    return
  end
  local capture_map = maps.org_capture_finalize
  capture_map.map_entry
    :with_handler(function()
      return self:refile()
    end)
    :attach(capture_map.default_map, capture_map.user_map, capture_map.opts)

  local refile_map = maps.org_capture_refile
  refile_map.map_entry
    :with_handler(function()
      return self:refile_to_destination()
    end)
    :attach(refile_map.default_map, refile_map.user_map, refile_map.opts)

  local kill_map = maps.org_capture_kill
  kill_map.map_entry
    :with_handler(function()
      return self:kill(true)
    end)
    :attach(kill_map.default_map, kill_map.user_map, kill_map.opts)
end

---@param template OrgCaptureTemplate
---@return OrgPromise<OrgCaptureWindow>
function Capture:open_template(template)
  self._window = CaptureWindow:new({
    template = template,
    on_open = function()
      return self:setup_mappings()
    end,
    on_close = function()
      return self:on_refile_close()
    end,
  })

  return self._window:open()
end

---@param shortcut string
function Capture:open_template_by_shortcut(shortcut)
  local template = self.templates:get_list()[shortcut]
  if not template then
    return utils.echo_error('No capture template with shortcut ' .. shortcut)
  end
  return self:open_template(template)
end

function Capture:on_refile_close()
  local is_modified = vim.bo.modified
  local opts = self:_get_refile_vars()
  if not opts then
    return
  end
  if is_modified then
    local choice =
      vim.fn.confirm(string.format('Do you want to refile this to %s?', opts.destination_file.filename), '&Yes\n&No')
    vim.cmd([[redraw!]])
    if choice ~= 1 then
      if self.on_cancel_refile then
        self.on_cancel_refile(self)
      end
      return utils.echo_info('Canceled.')
    end
  end

  vim.defer_fn(function()
    self:_refile_from_capture_buffer(opts)
    self._window = nil
  end, 0)
end

---Triggered when refiling from capture buffer
function Capture:refile()
  local opts = self:_get_refile_vars()
  if not opts then
    return
  end

  self:_refile_from_capture_buffer(opts)
end

---Refile to destination from capture buffer
function Capture:refile_to_destination()
  local source_file = self.files:get_current_file()
  local source_headline = source_file:get_headlines()[1]
  local destination = self:get_destination()
  self:_refile_from_capture_buffer({
    template = self._window.template,
    source_file = source_file,
    source_headline = source_headline,
    destination_file = destination.file,
    destination_headline = destination.headline,
  })
end

---Triggered from org file when we want to refile headline
function Capture:refile_headline_to_destination()
  return self:_refile_from_org_file({
    source_headline = self.files:get_closest_headline(),
  })
end

---@private
---@param opts OrgProcessCaptureOpts
function Capture:_refile_from_capture_buffer(opts)
  if self.on_pre_refile then
    self.on_pre_refile(self, opts)
  end
  local target_level = 0
  local target_line = -1
  local destination_file = opts.destination_file
  local destination_headline = opts.destination_headline

  if destination_headline then
    target_line = destination_headline:get_range().end_line
  end

  if opts.template.datetree then
    destination_headline, target_line = Datetree:new({ files = self.files }):create(opts.template)
  end

  if destination_headline then
    target_level = destination_headline:get_level()
  end

  local lines = opts.source_file.lines

  if opts.source_headline then
    lines = opts.source_headline:get_lines()
    if destination_headline or opts.source_headline:get_level() > 1 then
      lines = self:_adapt_headline_level(opts.source_headline, target_level, false)
    end
  end

  lines = opts.template:apply_properties_to_lines(lines)

  destination_file:update_sync(function(file)
    if not destination_headline and opts.template.regexp then
      local line = vim.fn.search(opts.template.regexp, 'ncw')
      if line > 0 then
        return vim.api.nvim_buf_set_lines(file:bufnr(), line, line, false, lines)
      end
    end

    local range = self:_get_destination_range_without_empty_lines(Range.from_line(target_line))
    vim.api.nvim_buf_set_lines(file:bufnr(), range.start_line, range.end_line, false, lines)
  end)

  if self.on_post_refile then
    self.on_post_refile(self, opts)
  end
  utils.echo_info(('Wrote %s'):format(destination_file.filename))
  self:kill()
  return true
end

---Refile a headline from a regular org file (non-capture)
---@private
---@param opts OrgProcessRefileOpts
---@return number
function Capture:_refile_from_org_file(opts)
  local source_headline = opts.source_headline
  local source_file = source_headline.file
  local destination_file = opts.destination_file
  local destination_headline = opts.destination_headline

  if not opts.destination_file then
    local destination = self:get_destination()
    destination_file = destination.file
    destination_headline = destination.headline
  end
  assert(destination_file)

  local is_same_file = source_file.filename == destination_file.filename

  local target_level = 0
  local target_line = -1

  if destination_headline then
    target_level = destination_headline:get_level()
    target_line = destination_headline:get_range().end_line
  end

  local lines = source_headline:get_lines()

  if destination_headline or source_headline:get_level() > 1 then
    lines = self:_adapt_headline_level(source_headline, target_level, is_same_file)
  end

  destination_file:update_sync(function(file)
    if is_same_file then
      local item_range = source_headline:get_range()
      return vim.cmd(string.format('silent! %d,%d move %s', item_range.start_line, item_range.end_line, target_line))
    end

    local range = self:_get_destination_range_without_empty_lines(Range.from_line(target_line))
    target_line = range.start_line
    vim.api.nvim_buf_set_lines(0, range.start_line, range.end_line, false, lines)
  end)

  if not is_same_file and source_file.filename == utils.current_file_path() then
    local item_range = source_headline:get_range()
    vim.api.nvim_buf_set_lines(0, item_range.start_line - 1, item_range.end_line, false, {})
  end

  utils.echo_info(opts.message or ('Wrote %s'):format(destination_file.filename))
  return target_line + 1
end

---@param headline OrgHeadline
function Capture:refile_file_headline_to_archive(headline)
  local file = headline.file

  if file:is_archive_file() then
    return utils.echo_warning('This file is already an archive file.')
  end

  local archive_location = file:get_archive_file_location()
  if not archive_location then
    return
  end

  local archive_directory = vim.fn.fnamemodify(archive_location, ':p:h')
  if vim.fn.isdirectory(archive_directory) == 0 then
    vim.fn.mkdir(archive_directory, 'p')
  end
  if not vim.loop.fs_stat(archive_location) then
    vim.fn.writefile({}, archive_location)
  end

  local destination_file = self.files:get(archive_location)
  local todo_state = headline:get_todo()

  local target_line = self:_refile_from_org_file({
    source_headline = headline,
    destination_file = destination_file,
    message = ('Archived to %s'):format(destination_file.filename),
  })

  destination_file = self.files:get(archive_location)
  destination_file:update(function(archive_file)
    local archived_headline = archive_file:get_closest_headline({ target_line, 0 })
    archived_headline:set_property('ARCHIVE_TIME', Date.now():to_string())
    archived_headline:set_property('ARCHIVE_FILE', file.filename)
    local outline_path = headline:get_outline_path()
    if outline_path ~= '' then
      archived_headline:set_property('ARCHIVE_OLPATH', outline_path)
    end
    archived_headline:set_property('ARCHIVE_CATEGORY', headline:get_category())
    archived_headline:set_property('ARCHIVE_TODO', todo_state or '')
  end)
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

--- Modify provided range to overwrite empty lines in the destination range
--- Example destination file:
--- ------------
--- * Headline 1
---
---
--- * Headline 2
--- ------------
--- Refiling "Headline 3" to "Headline 1" will remove empty line and we get this:
--- ------------
--- * Headline 1
--- ** Headline 3
--- * Headline 2
--- ------------
function Capture:_get_destination_range_without_empty_lines(range)
  local line_count = vim.api.nvim_buf_line_count(0)

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
  return range
end

--- Prompt for file (and headline) where to refile to
--- @return { file: OrgFile, headline?: OrgHeadline}
function Capture:get_destination()
  local valid_destinations = self:_get_autocompletion_files()

  local destination = vim.fn.OrgmodeInput('Enter destination: ', '', function(arg_lead)
    return self:autocomplete_refile(arg_lead, valid_destinations)
  end)

  local path = destination:match('^.*%.org/')
  local headline_title = path and destination:sub(#path + 1) or ''

  if not valid_destinations[path] then
    utils.echo_error(
      ('"%s" is not a is not a file specified in the "org_agenda_files" setting. Refiling cancelled.'):format(
        destination[1]
      )
    )
    return {}
  end

  local destination_file = valid_destinations[path]
  local result = {
    file = destination_file,
  }

  if not headline_title or vim.trim(headline_title) == '' then
    return result
  end

  local headlines = vim.tbl_filter(function(item)
    local pattern = '^' .. vim.pesc(headline_title:lower()) .. '$'
    return item:get_title():lower():match(pattern)
  end, destination_file:get_opened_unfinished_headlines())

  if not headlines[1] then
    utils.echo_error(
      ("'%s' is not a valid headline in '%s'. Refiling cancelled."):format(headline_title, destination_file.filename)
    )
    return {}
  end

  return {
    file = destination_file,
    headline = headlines[1],
  }
end

---@param arg_lead string
---@param files table<string, OrgFile>
---@return string[]
function Capture:autocomplete_refile(arg_lead, files)
  if not arg_lead or #arg_lead == 0 then
    return vim.tbl_keys(files)
  end

  local filename = arg_lead:match('^.*%.org/')

  local selected_file = filename and files[filename]

  if not selected_file then
    return vim.fn.matchfuzzy(vim.tbl_keys(files), filename or arg_lead)
  end

  local headlines = selected_file:get_opened_unfinished_headlines()
  local result = vim.tbl_map(function(headline)
    return string.format('%s%s', filename, headline:get_title())
  end, headlines)

  return vim.tbl_filter(function(item)
    return item:match(string.format('^%s', vim.pesc(arg_lead)))
  end, result)
end

function Capture:build_note_capture(title)
  return CaptureWindow:new({
    template = Template:new({
      template = '# ' .. title .. '\n\n%?',
    }),
    on_finish = function(content)
      local result = {}

      -- Remove lines from the beginning that are empty or comments
      -- until we find a non-empty line
      local trim_obsolete = true

      for _, line in ipairs(content) do
        local is_non_empty_line = not line:match('^%s*#%s') and vim.trim(line) ~= ''

        if trim_obsolete and is_non_empty_line then
          trim_obsolete = false
        end

        if not trim_obsolete then
          table.insert(result, line)
        end
      end

      if #result == 0 then
        return nil
      end

      local has_non_empty_line = vim.tbl_filter(function(line)
        return vim.trim(line) ~= ''
      end, result)

      if has_non_empty_line then
        return result
      end

      return nil
    end,
    on_open = function(capture_window)
      local maps = config:get_mappings('note', vim.api.nvim_get_current_buf())
      if not maps then
        return
      end
      local finalize_map = maps.org_note_finalize
      finalize_map.map_entry
        :with_handler(function()
          return capture_window:finish()
        end)
        :attach(finalize_map.default_map, finalize_map.user_map, finalize_map.opts)

      local kill_map = maps.org_note_kill
      kill_map.map_entry
        :with_handler(function()
          return capture_window:kill()
        end)
        :attach(kill_map.default_map, kill_map.user_map, kill_map.opts)
    end,
  })
end

---@param from_mapping? boolean
function Capture:kill(from_mapping)
  if self._window then
    if from_mapping and self.on_cancel_refile then
      self.on_cancel_refile(self)
    end
    self._window:kill()
    self._window = nil
  end
end

---@private
---@return OrgProcessCaptureOpts | false
function Capture:_get_refile_vars()
  local source_file = self.files:get_current_file()
  local source_headline = nil
  if not self._window.template.whole_file then
    source_headline = source_file:get_headlines()[1]
  end

  local opts = {
    source_file = source_file,
    source_headline = source_headline,
    destination_file = nil,
    destination_headline = nil,
    template = self._window.template,
  }

  if self.on_pre_refile then
    self.on_pre_refile(self, opts)
  end

  local file = opts.template:get_target()
  if vim.fn.filereadable(file) == 0 then
    local choice = vim.fn.confirm(('Refile destination %s does not exist. Create now?'):format(file), '&Yes\n&No')
    if choice ~= 1 then
      utils.echo_error('Cannot proceed without a valid refile destination')
      return false
    end
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':h'), 'p')
    vim.fn.writefile({}, file)
  end

  opts.destination_file = self.files:get(file)
  if opts.template.headline then
    opts.destination_headline = opts.destination_file:find_headline_by_title(opts.template.headline)
    if not opts.destination_headline then
      utils.echo_error(('Refile headline "%s" does not exist in "%s"'):format(opts.template.headline, file))
      return false
    end
  end

  return opts
end

---@deprecated
---@private
function Capture:_setup_closing_note()
  return self:build_note_capture('Insert note for closed todo item')
end

---@private
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

---@private
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

---@private
---@return table<string, OrgFile>
function Capture:_get_autocompletion_files()
  local valid_destinations = {}
  local filenames = {}
  for _, file in ipairs(self.files:all()) do
    if not file:is_archive_file() then
      table.insert(valid_destinations, file)
      table.insert(filenames, file.filename)
    end
  end

  filenames = fs.trim_common_root(filenames)
  local result = {}

  for i, filename in ipairs(filenames) do
    result[filename .. '/'] = valid_destinations[i]
  end

  return result
end

---@private
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

return Capture

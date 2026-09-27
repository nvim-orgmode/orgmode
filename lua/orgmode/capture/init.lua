local utils = require('orgmode.utils')
local fs = require('orgmode.utils.fs')
local config = require('orgmode.config')
local Templates = require('orgmode.capture.templates')
local Template = require('orgmode.capture.template')
local Menu = require('orgmode.ui.menu')
local Range = require('orgmode.files.elements.range')
local OrgFile = require('orgmode.files.file')
local CaptureWindow = require('orgmode.capture.window')
local Date = require('orgmode.objects.date')
local Datetree = require('orgmode.capture.template.datetree')
local Input = require('orgmode.ui.input')
local Promise = require('orgmode.utils.promise')
local MenuEntries = require('orgmode.capture.menu_entries')

---@return { mode: string, lhs: string }[] mappings of the current buffer in all modes
local function buffer_keymaps()
  local result = {}
  for _, mode in ipairs({ 'n', 'i', 'v', 'x', 's', 'o' }) do
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
      table.insert(result, { mode = mode, lhs = map.lhs })
    end
  end
  return result
end

---@alias OrgOnCaptureClose fun(capture:OrgCapture, opts:OrgProcessCaptureOpts)
---@alias OrgOnCaptureCancel fun(capture:OrgCapture)

---@class OrgCapture
---@field templates OrgCaptureTemplates
---@field closing_note OrgCaptureWindow
---@field files OrgFiles
---@field on_pre_refile OrgOnCaptureClose
---@field on_post_refile OrgOnCaptureClose
---@field on_cancel_refile OrgOnCaptureCancel
---@field private _windows table<number, OrgCaptureWindow>
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
  this._windows = {}
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
  template.files = self.files
  local window = CaptureWindow:new({
    template = template,
    resolve_file_target = function(capture_window, content)
      return self:_resolve_new_file_target(capture_window, content)
    end,
    on_open = function(capture_window)
      self._windows[capture_window.id] = capture_window
      local before = {}
      for _, map in ipairs(buffer_keymaps()) do
        before[map.mode .. map.lhs] = true
      end
      self:setup_mappings()
      -- A file capture hands its buffer over to the user when it ends, and
      -- the capture mappings must not stay behind in it.
      capture_window.mappings = vim.tbl_filter(function(map)
        return not before[map.mode .. map.lhs]
      end, buffer_keymaps())
    end,
    on_close = function(capture_window, event)
      return self:on_refile_close(capture_window, event)
    end,
  })

  return window:open()
end

---@param shortcut string
function Capture:open_template_by_shortcut(shortcut)
  local template = self.templates:get_list()[shortcut]
  if not template then
    return utils.echo_error('No capture template with shortcut ' .. shortcut)
  end
  return self:open_template(template)
end

---A whole_file capture into a file that does not exist yet edits that file
---directly instead of a temp buffer. Resolving the target runs on_pre_refile,
---so for whole_file captures it runs here, once, and not again on refile.
---@private
---@param capture_window OrgCaptureWindow
---@param content string[]
---@return string | nil
function Capture:_resolve_new_file_target(capture_window, content)
  local template = capture_window.template
  if not template.whole_file then
    return nil
  end
  local opts = {
    source_file = OrgFile:new({ filename = template:get_target(), lines = content }),
    template = template,
    capture_window = capture_window,
  }
  if self.on_pre_refile then
    self.on_pre_refile(self, opts)
  end
  capture_window.pre_refile_done = true
  local target = template:get_target()
  if vim.fn.filereadable(target) == 1 then
    return nil
  end
  return target
end

---@param capture_window OrgCaptureWindow
---@param event string the autocmd that closes the capture
function Capture:on_refile_close(capture_window, event)
  local file_target = capture_window:get_file_target()
  if capture_window:is_modified() then
    local choice = vim.fn.confirm(
      string.format('Do you want to refile this to %s?', capture_window.template:get_target()),
      '&Yes\n&No'
    )
    vim.cmd([[redraw!]])
    -- Escape keeps the capture open, which is impossible while Neovim exits
    if choice == 0 and event ~= 'VimLeavePre' then
      return capture_window:reopen()
    end
    local discard = choice == 2
    if discard and not (file_target and vim.fn.filereadable(file_target) == 1) then
      if self.on_cancel_refile then
        self.on_cancel_refile(self)
      end
      return utils.echo_info('Canceled.')
    end
    if not discard and file_target then
      vim.fn.writefile(vim.api.nvim_buf_get_lines(capture_window:get_bufnr(), 0, -1, false), file_target)
    end
  end

  if file_target then
    return vim.schedule(function()
      self:_finish_file_capture(capture_window)
    end)
  end

  local opts = self:_get_refile_vars(capture_window)
  if not opts then
    return
  end

  vim.schedule(function()
    self:_refile_from_capture_buffer(opts)
  end)
end

---Write a capture that edits its new file directly, and hand the file over as
---a normal buffer.
---@private
---@param capture_window OrgCaptureWindow
function Capture:_finish_file_capture(capture_window)
  local target = capture_window:get_file_target() --[[@as string]]
  local file = self.files:get(target)
  if self.on_post_refile then
    self.on_post_refile(self, {
      source_file = file,
      destination_file = file,
      template = capture_window.template,
      capture_window = capture_window,
    })
  end
  utils.echo_info(('Wrote %s'):format(target))
  self:_release_file_buffer(capture_window, '')
  self:kill(false, capture_window.id)
end

---Turn the capture buffer of a file capture into a normal buffer for its file.
---@private
---@param capture_window OrgCaptureWindow
---@param bufhidden string
function Capture:_release_file_buffer(capture_window, bufhidden)
  local bufnr = capture_window:get_bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  for _, map in ipairs(capture_window.mappings or {}) do
    pcall(vim.keymap.del, map.mode, map.lhs, { buffer = bufnr })
  end
  vim.bo[bufnr].bufhidden = bufhidden
  vim.bo[bufnr].buflisted = true
  vim.bo[bufnr].swapfile = vim.go.swapfile
  vim.b[bufnr].org_capture = nil
  vim.b[bufnr].org_capture_window_id = nil
end

---Abort a capture that edits its new file directly, as org-roam does in Emacs:
---the captured text goes without asking, and only deleting a file already on
---disk is asked for. The buffer stays loaded, so undo brings the text back.
---@private
---@param capture_window OrgCaptureWindow
function Capture:_kill_file_capture(capture_window)
  local target = capture_window:get_file_target() --[[@as string]]
  local bufnr = capture_window:get_bufnr()
  local on_disk = vim.fn.filereadable(target) == 1

  self:_release_file_buffer(capture_window, 'hide')
  -- Start a new undo block, so a single undo restores exactly the removed text
  vim.bo[bufnr].undolevels = vim.bo[bufnr].undolevels
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  if on_disk then
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd('silent write')
    end)
  end
  if self.on_cancel_refile then
    self.on_cancel_refile(self)
  end
  capture_window:kill()
  self._windows[capture_window.id] = nil

  if not on_disk then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  elseif vim.fn.confirm('Delete file for aborted capture?', '&No\n&Yes') == 2 then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    vim.fn.delete(target)
  end
  utils.echo_info('Canceled.')
end

---Triggered when refiling from capture buffer
function Capture:refile()
  local capture_window = self._windows[vim.b.org_capture_window_id]
  if capture_window:get_file_target() then
    vim.cmd('silent write')
    return self:_finish_file_capture(capture_window)
  end
  local opts = self:_get_refile_vars(capture_window)
  if not opts then
    return
  end

  self:_refile_from_capture_buffer(opts)
end

---Refile to destination from capture buffer
function Capture:refile_to_destination()
  local capture_window = self._windows[vim.b.org_capture_window_id]
  if capture_window:get_file_target() then
    utils.echo_error('A capture into a new file cannot be refiled elsewhere')
    return Promise.resolve(false)
  end
  local source_file = self.files:get_current_file()
  local source_headline = source_file:get_headlines()[1]
  return self:get_destination():next(function(destination)
    if not destination then
      return false
    end
    return self:_refile_from_capture_buffer({
      template = capture_window.template,
      capture_window = capture_window,
      source_file = source_file,
      source_headline = source_headline,
      destination_file = destination.file,
      destination_headline = destination.headline,
    })
  end)
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
  local prepend = opts.template.prepend

  if destination_headline then
    if prepend then
      target_line = destination_headline:get_range().start_line
    else
      target_line = destination_headline:get_range().end_line
    end
  elseif prepend then
    target_line = 0
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
  self:kill(false, opts.capture_window.id)
  return true
end

---Refile a headline from a regular org file (non-capture)
---@private
---@param opts OrgProcessRefileOpts
---@return OrgPromise<number>
function Capture:_refile_from_org_file(opts)
  local source_headline = opts.source_headline
  local source_file = source_headline.file
  local destination_file = opts.destination_file
  local destination_headline = opts.destination_headline

  return Promise.resolve()
    :next(function()
      if not opts.destination_file then
        return self:get_destination():next(function(destination)
          if not destination then
            return false
          end
          destination_file = destination.file
          destination_headline = destination.headline
          return destination
        end)
      end
    end)
    :next(function()
      if not destination_file then
        return false
      end

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

      destination_file:update_sync(function()
        if is_same_file then
          local item_range = source_headline:get_range()
          return vim.cmd(
            string.format('silent! %d,%d move %s', item_range.start_line, item_range.end_line, target_line)
          )
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
    end)
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
  if not vim.uv.fs_stat(archive_location) then
    vim.fn.writefile({}, archive_location)
  end

  local destination_file = self.files:get(archive_location)
  local todo_state = headline:get_todo()
  local headline_category = headline:get_category()
  local outline_path = headline:get_outline_path()

  return self
    :_refile_from_org_file({
      source_headline = headline,
      destination_file = destination_file,
      message = ('Archived to %s'):format(destination_file.filename),
    })
    :next(function(target_line)
      destination_file = self.files:get(archive_location)
      return destination_file:update(function(archive_file)
        local archived_headline = archive_file:get_closest_headline({ target_line, 0 })
        archived_headline:set_property('ARCHIVE_TIME', Date.now():to_string())
        archived_headline:set_property('ARCHIVE_FILE', file.filename)
        if outline_path ~= '' then
          archived_headline:set_property('ARCHIVE_OLPATH', outline_path)
        end
        archived_headline:set_property('ARCHIVE_CATEGORY', headline_category)
        archived_headline:set_property('ARCHIVE_TODO', todo_state or '')
      end)
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
--- @return OrgPromise<{ file: OrgFile, headline?: OrgHeadline}>
function Capture:get_destination()
  local valid_destinations = self:_get_autocompletion_files()

  return Input.open('Enter destination: ', '', function(arg_lead)
    return self:autocomplete_refile(arg_lead, valid_destinations)
  end):next(function(destination)
    if not destination then
      return false
    end

    local path = destination:match('^.*%.org/?')
    local headline_title = path and destination:sub(#path + 1) or ''

    if not vim.endswith(path, '/') then
      path = path .. '/'
    end

    if not valid_destinations[path] then
      utils.echo_error(
        ('"%s" is not a is not a file specified in the "org_agenda_files" setting. Refiling cancelled.'):format(path)
      )
      return false
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
  end)
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
    on_close = function(capture_window)
      local is_modified = vim.bo.modified

      if is_modified then
        local choice = vim.fn.confirm('Do you want to capture this note?', '&Yes\n&No')
        vim.cmd([[redraw!]])
        if choice ~= 1 then
          return utils.echo_info('Canceled.')
        end
      end

      capture_window:finish()
    end,
  })
end

---@param from_mapping? boolean
---@param window_id? number
function Capture:kill(from_mapping, window_id)
  local window = self._windows[window_id or vim.b.org_capture_window_id]
  if window and from_mapping and window:get_file_target() then
    return self:_kill_file_capture(window)
  end
  if window then
    if from_mapping and self.on_cancel_refile then
      self.on_cancel_refile(self)
    end
    window:kill()
    self._windows[window.id] = nil
  end
end

---@private
---@param capture_window OrgCaptureWindow
---@return OrgProcessCaptureOpts | false
function Capture:_get_refile_vars(capture_window)
  local source_file = self.files:get(vim.api.nvim_buf_get_name(capture_window:get_bufnr()))
  local source_headline = nil
  if not capture_window.template.whole_file then
    source_headline = source_file:get_headlines()[1]
  end

  local opts = {
    source_file = source_file,
    source_headline = source_headline,
    destination_file = nil,
    destination_headline = nil,
    template = capture_window.template,
    capture_window = capture_window,
  }

  if self.on_pre_refile and not capture_window.pre_refile_done then
    self.on_pre_refile(self, opts)
  end

  local file = opts.template:get_target()
  if vim.fn.filereadable(file) == 0 then
    -- A whole_file template captures into the target file itself, so creating
    -- that file is the capture, not a side effect worth confirming.
    if not opts.template.whole_file then
      local choice = vim.fn.confirm(('Refile destination %s does not exist. Create now?'):format(file), '&Yes\n&No')
      if choice ~= 1 then
        utils.echo_error('Cannot proceed without a valid refile destination')
        return false
      end
    end
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':h'), 'p')
    vim.fn.writefile({}, file)
  end

  opts.destination_file = self.files:get(file)
  if opts.template.headline then
    local template_headline = opts.template.headline
    if type(template_headline) == 'function' then
      local ok, resolved_headline = pcall(template_headline, opts.destination_file)
      if not ok then
        utils.echo_error('Failed to resolve capture template headline')
        return false
      end
      template_headline = resolved_headline
    end
    if type(template_headline) ~= 'string' then
      utils.echo_error('Capture template headline function must return a string')
      return false
    end

    opts.destination_headline = opts.destination_file:find_headline_by_title(template_headline)
    if not opts.destination_headline then
      utils.echo_error(('Refile headline "%s" does not exist in "%s"'):format(template_headline, file))
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
---@param templates table<string, OrgCaptureTemplate>
function Capture:_create_menu_items(templates)
  return vim.tbl_map(function(entry)
    if entry.template then
      return {
        key = entry.key,
        label = entry.label,
        action = function()
          return self:open_template(entry.template)
        end,
      }
    end
    return {
      key = entry.key,
      label = entry.label .. '...',
      action = function()
        self:_create_prompt(entry.subtemplates)
      end,
    }
  end, MenuEntries.entries(templates))
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

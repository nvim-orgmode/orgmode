local utils = require('orgmode.utils')
local config = require('orgmode.config')
local Files = require('orgmode.parser.files')
local File = require('orgmode.parser.file')
local Templates = require('orgmode.capture.templates')

local capture_augroup = vim.api.nvim_create_augroup('OrgCapture', { clear = true })

---@class Capture
---@field templates Templates
local Capture = {}

function Capture:new()
  local data = {}
  data.templates = Templates:new()
  setmetatable(data, self)
  self.__index = self
  return data
end

function Capture:_get_subtemplates(base_key, templates)
  local subtemplates = {}
  for key, template in pairs(templates) do
    if string.len(key) > 1 and string.sub(key, 1, 1) == base_key then
      subtemplates[string.sub(key, 2, string.len(key))] = template
    end
  end
  return subtemplates
end

function Capture:_create_menu_items(templates)
  local menu_items = {}
  for key, template in pairs(templates) do
    if string.len(key) == 1 then
      local item = {
        key = key,
      }
      if type(template) == 'string' then
        item['label'] = template .. '...'
        item['action'] = function()
          self:_create_prompt(self:_get_subtemplates(key, templates))
        end
      else
        item['label'] = template.description
        item['action'] = function()
          return self:open_template(template)
        end
      end
      table.insert(menu_items, item)
    end
  end
  return menu_items
end

function Capture:_create_prompt(templates)
  local menu_items = self:_create_menu_items(templates)
  table.insert(menu_items, { label = '', key = '', separator = '-' })
  table.insert(menu_items, { label = 'Quit', key = 'q' })
  table.insert(menu_items, { label = '', separator = ' ', length = 1 })

  return utils.menu('Select a capture template', menu_items, 'Template key')
end

function Capture:prompt()
  self:_create_prompt(self.templates:get_list())
end

---@param template table
function Capture:open_template(template)
  local content = self.templates:compile(template)
  local winnr = vim.api.nvim_get_current_win()
  utils.open_window(vim.fn.tempname(), 16, config.win_split_mode)
  vim.cmd([[setf org]])
  vim.cmd([[setlocal bufhidden=wipe nobuflisted nolist noswapfile nofoldenable]])
  vim.api.nvim_buf_set_lines(0, 0, -1, true, content)
  self.templates:setup()
  vim.api.nvim_buf_set_var(0, 'org_template', template)
  vim.api.nvim_buf_set_var(0, 'org_capture', true)
  vim.api.nvim_buf_set_var(0, 'org_prev_window', winnr)
  config:setup_mappings('capture')

  self.wipeout_autocmd_id = vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = 0,
    group = capture_augroup,
    callback = function()
      require('orgmode').action('capture.refile', true)
    end,
    once = true,
  })
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
  local file, lines, item, template = self:_get_refile_vars()
  local headline_title = template.headline
  if confirm and is_modified then
    local choice = vim.fn.confirm(string.format('Do you want to refile this to %s?', file), '&Yes\n&No')
    vim.cmd([[redraw!]])
    if choice ~= 1 then
      return utils.echo_info('Canceled.')
    end
  end
  vim.defer_fn(function()
    if headline_title then
      self:refile_to_headline(file, lines, item, headline_title)
    else
      self:_refile_to_end(file, lines, item)
    end

    if not confirm then
      self:kill()
    end
  end, 0)
end

---Triggered when refiling to destination from capture buffer
function Capture:refile_to_destination()
  local file, lines, item = self:_get_refile_vars()
  self:_refile_content_with_fallback(lines, file, item)
  self:kill()
end

---@private
function Capture:_get_refile_vars()
  local template = vim.api.nvim_buf_get_var(0, 'org_template') or {}
  local file = vim.fn.resolve(vim.fn.fnamemodify(template.target or config.org_default_notes_file, ':p'))
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  local org_file = File.from_content(lines, 'capture', utils.current_file_path())
  local item = nil
  if org_file then
    item = org_file:get_headlines()[1]
  end

  return file, lines, item, template
end

---Triggered from org file when we want to refile headline
function Capture:refile_headline_to_destination()
  local destination_file = Files.get_current_file()
  local item = destination_file:get_closest_headline()
  local lines = destination_file:get_headline_lines(item)
  return self:_refile_content_with_fallback(lines, nil, item)
end

---@param file File
---@param item string
---@param archive_file string
---@return string
function Capture:refile_file_headline_to_archive(file, item, archive_file)
  local lines = file:get_headline_lines(item)
  return self:_refile_to_end(archive_file, lines, item, string.format('Archived to %s', archive_file))
end

---@private
---@param file string
---@param lines string[]
---@param item? Section
---@param message? string
---@return boolean
function Capture:_refile_to_end(file, lines, item, message)
  local refiled = self:_refile_to(file, lines, item, '$')
  if not refiled then
    return false
  end
  utils.echo_info(message or string.format('Wrote %s', file))
  return true
end

---@private
---@param lines string[]
---@param fallback_file string
---@param item? Section
---@return string
function Capture:_refile_content_with_fallback(lines, fallback_file, item)
  local default_file = fallback_file and fallback_file ~= '' and vim.fn.fnamemodify(fallback_file, ':p') or nil

  local valid_destinations = {}
  for _, file in ipairs(Files.filenames()) do
    valid_destinations[vim.fn.fnamemodify(file, ':t')] = file
  end

  local destination = vim.fn.OrgmodeInput('Enter destination: ', '', self.autocomplete_refile)
  destination = vim.split(destination, '/', true)

  if not valid_destinations[destination[1]] then
    if not default_file then -- we know that this comes from org_refile and not org_capture_refile
      utils.echo_error(
        "'" .. destination[1] .. "' is not a file specified in the 'org_agenda_files' setting. Refiling cancelled."
      )
      return
    end
    return self:_refile_to_end(default_file, lines, item)
  end

  local destination_file = valid_destinations[destination[1]]
  local destination_headline = destination[2]
  if not destination_headline or destination_headline == '' then
    return self:_refile_to_end(destination_file, lines, item)
  end
  return self:refile_to_headline(destination_file, lines, item, destination_headline)
end

---@param destination_filename string
---@param lines string[]
---@param item? Section
---@param headline_title? string
function Capture:refile_to_headline(destination_filename, lines, item, headline_title)
  local destination_file = Files.get(destination_filename)
  local headline
  if headline_title then
    headline = destination_file:find_headline_by_title(headline_title, true)

    if not headline then
      utils.echo_error(
        "headline '" .. headline_title .. "' does not exist in '" .. destination_filename .. "'. Aborted refiling."
      )
      return false
    end
  end

  if item and item.level <= headline.level then
    -- Refiling in same file just moves the lines from one position
    -- to another,so we need to apply demote instantly
    local is_same_file = destination_file.filename == item.root.filename
    lines = item:demote(headline.level - item.level + 1, true, not is_same_file)
  end
  local refiled = self:_refile_to(destination_filename, lines, item, headline.range.end_line)
  if not refiled then
    return false
  end
  utils.echo_info(string.format('Wrote %s', destination_filename))
  return true
end

---@private
---@param file string
---@param lines string[]
---@param item? Section
---@param destination_line string|number
---@return boolean
function Capture:_refile_to(file, lines, item, destination_line)
  if not file then
    return false
  end

  local is_same_file = file == utils.current_file_path()
  local cur_win = vim.api.nvim_get_current_win()

  if is_same_file and item then
    vim.cmd(
      string.format('silent! %d,%d move %s', item.range.start_line, item.range.end_line, tostring(destination_line))
    )
    return true
  end

  if not is_same_file then
    local bufnr = vim.fn.bufadd(file)
    vim.api.nvim_open_win(bufnr, true, {
      relative = 'editor',
      width = 1,
      height = 1,
      row = 99999,
      col = 99999,
      zindex = 1,
      style = 'minimal',
    })
  end

  vim.fn.append(destination_line, lines)

  if not is_same_file then
    vim.cmd('silent! wq!')
    vim.api.nvim_set_current_win(cur_win)
  end

  if item and item.file == utils.current_file_path() then
    vim.api.nvim_buf_set_lines(0, item.range.start_line - 1, item.range.end_line, false, {})
  end

  return true
end

---@param arg_lead string
---@return string[]
function Capture.autocomplete_refile(arg_lead)
  local valid_filenames = {}
  for _, filename in ipairs(Files.filenames()) do
    valid_filenames[vim.fn.fnamemodify(filename, ':t') .. '/'] = filename
  end

  if not arg_lead then
    return vim.tbl_keys(valid_filenames)
  end
  local parts = vim.split(arg_lead, '/', true)

  local selected_file = valid_filenames[parts[1] .. '/']

  if not selected_file then
    return vim.tbl_filter(function(file)
      return file:match('^' .. vim.pesc(parts[1]))
    end, vim.tbl_keys(valid_filenames))
  end

  local agenda_file = Files.get(selected_file)
  if not agenda_file then
    return {}
  end

  local headlines = agenda_file:get_opened_unfinished_headlines()
  local result = vim.tbl_map(function(headline)
    return string.format('%s/%s', vim.fn.fnamemodify(headline.file, ':t'), headline.title)
  end, headlines)

  return vim.tbl_filter(function(item)
    return item:match(string.format('^%s', vim.pesc(arg_lead)))
  end, result)
end

function Capture:kill()
  if self.wipeout_autocmd_id then
    vim.api.nvim_del_autocmd(self.wipeout_autocmd_id)
    self.wipeout_autocmd_id = nil
  end
  local prev_winnr = vim.api.nvim_buf_get_var(0, 'org_prev_window')
  vim.api.nvim_win_close(0, true)
  if prev_winnr and vim.api.nvim_win_is_valid(prev_winnr) then
    vim.api.nvim_set_current_win(prev_winnr)
  end
end

return Capture

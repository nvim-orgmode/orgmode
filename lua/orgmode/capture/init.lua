_G.org.capture = {}
local utils = require('orgmode.utils')
local Types = require('orgmode.parser.types')
local config = require('orgmode.config')
local Templates = require('orgmode.capture.templates')
vim.cmd[[augroup OrgCapture]]
vim.cmd[[autocmd!]]
vim.cmd[[augroup END]]

---@class Capture
---@field templates Templates
---@field files OrgFiles
local Capture = {}

function Capture:new(opts)
  local data = {}
  data.templates = Templates:new()
  data.files = opts.files
  setmetatable(data, self)
  self.__index = self
  return data
end

function Capture:prompt()
  local templates = {}
  for key, template in pairs(self.templates:get_list()) do
    table.insert(templates, {
      label = template.description,
      key = key,
      action = function() return self:open_template(template) end
    })
  end
  table.insert(templates, { label = '', key = '', separator = '-' })
  table.insert(templates, { label = 'Quit', key = 'q' })

  return utils.menu('Select a capture template', templates, 'Template key')
end

function Capture:open_template(template)
  vim.cmd('16split '..vim.fn.tempname())
  vim.cmd[[setf org]]
  vim.cmd[[setlocal bufhidden=wipe nobuflisted nolist noswapfile nowrap]]
  vim.api.nvim_buf_set_lines(0, 0, -1, true, self.templates:compile(template))
  self.templates:setup()
  vim.api.nvim_buf_set_var(0, 'org_template', template)
  vim.api.nvim_buf_set_var(0, 'org_capture', true)
  config:setup_mappings('capture')
  vim.cmd[[autocmd OrgCapture BufWipeout <buffer> ++once lua require('orgmode').action('capture.refile', true)]]
end

---Triggered when refiling from capture buffer
---@param confirm boolean
---@return string
function Capture:refile(confirm)
  local is_modified = vim.bo.modified
  local template = vim.api.nvim_buf_get_var(0, 'org_template') or {}
  local file = vim.fn.fnamemodify(template.target or config.org_default_notes_file, ':p')
  if confirm and is_modified then
    local choice = vim.fn.confirm(string.format('Do you want to refile this to %s?', file), '&Yes\n&No')
    vim.cmd[[redraw!]]
    if choice ~= 1 then
      return utils.echo_info('Canceled.')
    end
  end
  local lines = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, true), '\n')..'\n'
  self:_refile_to_end(file, lines)
  vim.cmd[[autocmd! OrgCapture BufWipeout <buffer>]]
  vim.cmd[[silent! wq]]
end

---Triggered when refiling to destination from capture buffer
function Capture:refile_to_destination()
  local template = vim.api.nvim_buf_get_var(0, 'org_template')
  local lines_list = vim.api.nvim_buf_get_lines(0, 0, -1, true)
  local default_file = vim.fn.fnamemodify(template.target or config.org_default_notes_file, ':p')

  self:_refile_content_with_fallback(lines_list, default_file)
  vim.cmd[[autocmd! OrgCapture BufWipeout <buffer>]]
  vim.cmd[[silent! wq]]
end

---Triggered from org file when we want to refile headline
function Capture:refile_headline_to_destination()
  local agenda_file = self.files:get_current_file()
  local item = agenda_file.items[vim.fn.line('.')]
  if item.type ~= Types.HEADLINE then
    item = agenda_file.items[item.parent]
  end
  local lines = {unpack(agenda_file.lines, item.range.start_line, item.range.end_line)}
  self:_refile_content_with_fallback(lines, nil)
  vim.cmd(string.format(':silent %d,%ddelete', item.range.start_line, item.range.end_line))
end

function Capture:_refile_to_end(file, lines)
  if not file then return end
  utils.writefile(file, lines, 'a')
  self.files:reload(file)
  return utils.echo_info(string.format('Wrote %s', file))
end

function Capture:_refile_content_with_fallback(lines_list, fallback_file)
  local lines = table.concat(lines_list, '\n')..'\n'
  local default_file = fallback_file and fallback_file ~= '' and vim.fn.fnamemodify(fallback_file, ':p') or nil

  local valid_destinations = {}
  for _, file in ipairs(self.files:filenames()) do
    valid_destinations[vim.fn.fnamemodify(file, ':t')] = file
  end

  local destination = vim.fn.input('Enter destination: ', '', 'customlist,v:lua.org.autocomplete_refile')
  destination = vim.split(destination, '/', true)

  if not valid_destinations[destination[1]] then
    return self:_refile_to_end(default_file, lines)
  end

  local destination_file = valid_destinations[destination[1]]

  if not destination[2] or destination[2] == '' then
    return self:_refile_to_end(destination_file, lines)
  end

  local agenda_file = self.files:get(destination_file)
  local headline = agenda_file:find_headline_by_title(destination[2])
  if not headline then
    return self._refile_to_end(destination_file, lines)
  end

  -- TODO:
  -- * Keep it in sync by tracking the exact position of headline/item
  -- * Nest under headline with bigger level
  local content = agenda_file.lines
  local start = headline.range.end_line
  for i, line in ipairs(lines_list) do
    table.insert(content, start + i, line)
  end
  local lines_str = table.concat(content, '\n')..'\n'
  utils.writefile(destination_file, lines_str, 'w')
  self.files:reload(destination_file)
  return utils.echo_info(string.format('Wrote %s', destination_file))
end

function Capture:autocomplete_refile(arg_lead)
  local valid_filenames = {}
  for _, filename in ipairs(self.files:filenames()) do
    valid_filenames[vim.fn.fnamemodify(filename, ':t')..'/'] = filename
  end

  if not arg_lead then return vim.tbl_keys(valid_filenames) end
  local parts = vim.split(arg_lead, '/', true)

  local selected_file = valid_filenames[parts[1]..'/']

  if not selected_file then
    return vim.tbl_filter(function(file)
      return file:match('^'..vim.pesc(parts[1]))
    end, vim.tbl_keys(valid_filenames))
  end

  local agenda_file = self.files:get(selected_file)
  if not agenda_file then return {} end

  local headlines = agenda_file:get_opened_unfinished_headlines()
  local result = vim.tbl_map(function(headline)
    return string.format('%s/%s', vim.fn.fnamemodify(headline.file, ':t'), headline.title)
  end, headlines)

  return vim.tbl_filter(function(item)
    return item:match(string.format('^%s', vim.pesc(arg_lead)))
  end, result)
end

function _G.org.autocomplete_refile(arg_lead)
  return require('orgmode').action('capture.autocomplete_refile', arg_lead)
end

function Capture:kill()
  vim.cmd[[bw!]]
end

return Capture

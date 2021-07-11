local Calendar = require('orgmode.objects.calendar')
local Date = require('orgmode.objects.date')
local TodoState = require('orgmode.objects.todo_state')
local Hyperlinks = require('orgmode.org.hyperlinks')
local utils = require('orgmode.utils')
local Files = require('orgmode.parser.files')
local config = require('orgmode.config')
local Help = require('orgmode.objects.help')

---@class OrgMappings
---@field files OrgFiles
---@field capture Capture
---@field agenda Agenda
local OrgMappings = {}

---@param data table
function OrgMappings:new(data)
  local opts = {}
  opts.global_cycle_mode = 'all'
  opts.capture = data.capture
  opts.agenda = data.agenda
  setmetatable(opts, self)
  self.__index = self
  return opts
end

-- TODO:
-- Support archiving to headline
function OrgMappings:archive()
  local file = Files.get_current_file()
  if file.is_archive_file then
    return utils.echo_warning('This file is already an archive file.')
  end
  local item = file:get_closest_headline()
  file = Files.get_current_file()
  item = file:get_closest_headline()
  local archive_location = file:get_archive_file_location()
  self.capture:refile_file_headline_to_archive(file, item, archive_location)
  Files.reload(archive_location, vim.schedule_wrap(function()
    Files.update_file(archive_location, function(archive_file)
      local last_item = archive_file:get_closest_headline(vim.fn.line('$'))
      if not last_item then return end
      last_item:add_properties({
        ARCHIVE_TIME = Date.now():to_string(),
        ARCHIVE_FILE = file.file,
        ARCHIVE_CATEGORY = item.category,
        ARCHIVE_TODO = item.todo_keyword.value,
      })
    end)
  end))
end

function OrgMappings:set_tags()
  local headline = Files.get_current_file():get_closest_headline()
  local own_tags = headline:get_own_tags()
  local tags = vim.fn.input('Tags: ', utils.tags_to_string(own_tags), 'customlist,v:lua.orgmode.autocomplete_set_tags')
  return self:_set_headline_tags(headline, tags)
end

function OrgMappings:toggle_archive_tag()
  local headline = Files.get_current_file():get_closest_headline()
  local own_tags = headline:get_own_tags()
  if vim.tbl_contains(own_tags, 'ARCHIVE') then
    own_tags = vim.tbl_filter(function(tag) return tag ~= 'ARCHIVE' end, own_tags)
  else
    table.insert(own_tags, 'ARCHIVE')
  end
  return self:_set_headline_tags(headline, utils.tags_to_string(own_tags))
end

function OrgMappings:cycle()
  local is_fold_closed = vim.fn.foldclosed('.') ~= -1
  if is_fold_closed then
    return vim.cmd[[norm!zo]]
  end
  vim.cmd[[norm!j]]
  local is_next_item_closed = vim.fn.foldclosed('.') ~= -1
  vim.cmd[[norm!k]]
  if is_next_item_closed then
    return vim.cmd[[norm!zczO]]
  end
  if vim.fn.foldlevel('.') == 1 then
    return vim.cmd[[norm!zCzxzc]]
  end
  return vim.cmd[[norm!zc]]
end

function OrgMappings:global_cycle()
  if not vim.wo.foldenable or self.global_cycle_mode == 'Show All' then
    self.global_cycle_mode = 'Overview'
    utils.echo_info(self.global_cycle_mode)
    return vim.cmd([[norm!zM]])
  end
  if self.global_cycle_mode == 'Contents' then
    self.global_cycle_mode = 'Show All'
    utils.echo_info(self.global_cycle_mode)
    return vim.cmd([[norm!zR]])
  end
  self.global_cycle_mode = 'Contents'
  utils.echo_info(self.global_cycle_mode)
  vim.wo.foldlevel = 1
  return vim.cmd([[norm!zx]])
end

-- TODO: Add hierarchy
function OrgMappings:toggle_checkbox()
  local line = vim.fn.getline('.')
  local pattern = '^(%s*[%-%+]%s*%[([%sXx%-]?)%])'
  local checkbox, state = line:match(pattern)
  if not checkbox then return end
  local new_val = vim.trim(state) == '' and '[X]' or '[ ]'
  checkbox = checkbox:gsub('%[[%sXx%-]?%]$', new_val)
  local new_line = line:gsub(pattern, checkbox)
  vim.fn.setline('.', new_line)
end

function OrgMappings:increase_date()
  return self:_adjust_date('+1d', config.mappings.org.org_increase_date, '<C-a>')
end

function OrgMappings:decrease_date()
  return self:_adjust_date('-1d', config.mappings.org.org_decrease_date, '<C-x>')
end

function OrgMappings:change_date()
  local date = self:_get_date_under_cursor()
  if not date then return end
  local cb = function(new_date)
    self:_replace_date(new_date)
  end
  Calendar.new({ callback = cb, date = date }).open()
end

function OrgMappings:todo_next_state()
  local item = Files.get_current_file():get_closest_headline()
  local was_done = item:is_done()
  local old_state = item.todo_keyword.value
  self:_change_todo_state('next')
  item = Files.get_current_file():get_closest_headline()
  if not item:is_done() and not was_done then return item end

  local repeater_dates = item:get_repeater_dates()
  if #repeater_dates == 0 then
    local log_time = config.org_log_done == 'time'
    if log_time and item:is_done() and not was_done then
      item:add_closed_date()
    end
    if log_time and not item:is_done() and was_done then
      item:remove_closed_date()
    end
    return item
  end

  for _, date in ipairs(repeater_dates) do
    self:_replace_date(date:apply_repeater())
  end

  self:_change_todo_state('reset')
  local state_change = string.format('- State "%s" from "%s" [%s]', item.todo_keyword.value, old_state, Date.now():to_string())

  local data = item:add_properties({ LAST_REPEAT = Date.now():to_string() })
  if data.is_new then
    vim.fn.append(data.end_line, state_change)
    return item
  end
  item = Files.get_current_file():get_closest_headline()

  if item.properties.valid then
    vim.fn.append(item.properties.range.end_line, state_change)
  end
end

function OrgMappings:todo_prev_state()
  self:_change_todo_state('prev')
end

function OrgMappings:do_promote(whole_subtree)
  local item = Files.get_current_file():get_closest_headline()
  return item:promote(1, whole_subtree)
end

function OrgMappings:do_demote(whole_subtree)
  local item = Files.get_current_file():get_closest_headline()
  return item:demote(1, whole_subtree)
end

function OrgMappings:handle_return(suffix)
  suffix = suffix or ''
  local item = Files.get_current_file():get_current_item()
  if item:is_headline() then
    vim.fn.append(vim.fn.line('.'), {'', string.rep('*', item.level)..' '..suffix})
    vim.fn.cursor(vim.fn.line('.') + 2, 0)
    return vim.cmd[[startinsert!]]
  end
  local checkbox = item:is_checkbox()
  if checkbox then
    vim.fn.append(vim.fn.line('.'), checkbox..' [ ] ')
    vim.fn.cursor(vim.fn.line('.') + 1, 0)
    return vim.cmd[[startinsert!]]
  end
  local plain_list = item:is_plain_list()
  if plain_list then
    vim.fn.append(vim.fn.line('.'), plain_list)
    vim.fn.cursor(vim.fn.line('.') + 1, 0)
    return vim.cmd[[startinsert!]]
  end
end

function OrgMappings:insert_heading_respect_content(suffix)
  suffix = suffix or ''
  local item = Files.get_current_file():get_closest_headline()
  local line = {string.rep('*', item.level)..' '..suffix, ''}
  if #item.content > 0 and vim.trim(item.content[#item.content].line) ~= '' then
    table.insert(line, 1, '')
  end
  vim.fn.append(item.range.end_line, line)
  vim.fn.cursor(item.range.end_line + #line - 1, 0)
  return vim.cmd[[startinsert!]]
end

function OrgMappings:insert_todo_heading_respect_content()
  return self:insert_heading_respect_content(config:get_todo_keywords().TODO[1]..' ')
end

function OrgMappings:insert_todo_heading()
  local item = Files.get_current_file():get_closest_headline()
  vim.fn.cursor(item.range.start_line, 0)
  return self:handle_return(config:get_todo_keywords().TODO[1]..' ')
end

function OrgMappings:move_subtree_up()
  local item = Files.get_current_file():get_closest_headline()
  local prev_headline = item:get_prev_headline_same_level()
  if not prev_headline then
    return utils.echo_warning('Cannot move past superior level.')
  end
  vim.cmd(string.format(':%d,%dmove %d', item.range.start_line, item.range.end_line, prev_headline.range.start_line - 1))
end

function OrgMappings:move_subtree_down()
  local item = Files.get_current_file():get_closest_headline()
  local next_headline = item:get_next_headline_same_level()
  if not next_headline then
    return utils.echo_warning('Cannot move past superior level.')
  end
  vim.cmd(string.format(':%d,%dmove %d', item.range.start_line, item.range.end_line, next_headline.range.end_line))
end

function OrgMappings:show_help()
  return Help.show()
end

function OrgMappings:open_at_point()
  local date = self:_get_date_under_cursor()
  if date then
    return self.agenda:open_day(date)
  end

  local link = self:_get_link_under_cursor()
  if not link then return end
  local parts = vim.split(link, '][', true)
  local url = parts[1]
  if url:find('^file:') then
      if url:find(' +') then
          parts = vim.split(url, ' +', true)
          url = parts[1]
          local line_number = parts[2]
          return vim.cmd(string.format('edit +%s %s', line_number ,url:sub(6)))
      end
      return vim.cmd(string.format('edit %s', url:sub(6)))
  end
  if url:find('^https?://') then
    if not vim.g.loaded_netrwPlugin then
      return utils.echo_warning('Netrw plugin must be loaded in order to open urls.')
    end
    return vim.fn['netrw#BrowseX'](url, vim.fn['netrw#CheckIfRemote']())
  end
  local stat = vim.loop.fs_stat(url)
  if stat and stat.type == 'file' then
    return vim.cmd(string.format('edit %s', url))
  end
  local current_headline = Files.get_current_file():get_closest_headline()
  local headlines = vim.tbl_filter(function(headline)
    return headline.line ~= current_headline.line and headline.id ~= current_headline.id
  end, Hyperlinks.find_matching_links(url, true))
  if #headlines == 0 then return end
  local headline = headlines[1]
  if #headlines > 1 then
    local longest_headline = utils.reduce(headlines, function(acc, h)
      return math.max(acc, h.line:len())
    end, 0)
    local options = {}
    for i, h in ipairs(headlines) do
      table.insert(options, string.format('%d) %-'..(longest_headline)..'s (%s)', i, h.line, h.file))
    end
    vim.cmd[[echo "Multiple targets found. Select target:"]]
    local choice = vim.fn.inputlist(options)
    if choice < 1 or choice > #headlines then return end
    headline = headlines[choice]
  end
  vim.cmd(string.format('edit %s', headline.file))
  vim.fn.cursor(headline.range.start_line, 0)
end

function OrgMappings:export()
  return require('orgmode.export').prompt()
end

---@param direction string
function OrgMappings:_change_todo_state(direction)
  local item = Files.get_current_file():get_closest_headline()
  local todo = item.todo_keyword
  local todo_state = TodoState:new({ current_state = todo.value })
  local next_state = nil
  if direction == 'next' then
    next_state = todo_state:get_next()
  elseif direction == 'prev' then
    next_state = todo_state:get_prev()
  elseif direction == 'reset' then
    next_state = todo_state:get_todo()
  end

  local linenr = item.range.start_line
  local stars = string.rep('%*', item.level)
  local old_state = todo.value
  if old_state ~= '' then
    old_state = old_state..'%s+'
  end
  local new_state = next_state.value
  if new_state ~= '' then
    new_state = new_state..' '
  end
  local new_line = vim.fn.getline(linenr):gsub('^'..stars..'%s+'..old_state, stars..' '..new_state)
  vim.fn.setline(linenr, new_line)
end

---@param date Date
function OrgMappings:_replace_date(date)
  local line = vim.fn.getline(date.range.start_line)
  local view = vim.fn.winsaveview()
  vim.fn.setline(date.range.start_line, string.format('%s%s%s', line:sub(1, date.range.start_col), date:to_string(), line:sub(date.range.end_col)))
  vim.fn.winrestview(view)
end

---@return Date|nil
function OrgMappings:_get_date_under_cursor()
  local item = Files.get_current_item()
  local col = vim.fn.col('.')
  local line = vim.fn.line('.')
  local dates = vim.tbl_filter(function(date)
    return date.range:is_in_range(line, col)
  end, item.dates)

  if #dates == 0 then return nil end

  return dates[1]
end

---@param adjustment string
---@param fallback string
---@param vim_mapping string
---@return string
function OrgMappings:_adjust_date(adjustment, fallback, vim_mapping)
  local date = self:_get_date_under_cursor()
  if date then
    local new_date = date:adjust(adjustment)
    return self:_replace_date(new_date)
  end

  if fallback ~= vim_mapping then
    return vim.api.nvim_feedkeys(utils.esc(fallback), 'n', true)
  end

  local num = vim.fn.search([[\d]], 'c', vim.fn.line('.'))
  if num == 0 then
    return vim.api.nvim_feedkeys(utils.esc(fallback), 'n', true)
  end

  date = self:_get_date_under_cursor()
  if date then
    local new_date = date:adjust(adjustment)
    return self:_replace_date(new_date)
  end

  return vim.api.nvim_feedkeys(utils.esc(fallback), 'n', true)
end

function OrgMappings:_set_headline_tags(headline, tags_string)
  local tags = tags_string:gsub('^:+', ''):gsub(':+$', ''):gsub(':+', ':')
  if tags ~= '' then
    tags = ':'..tags..':'
  end
  local line_without_tags = headline.line:gsub(vim.pesc(utils.tags_to_string(headline:get_own_tags()))..'%s*$', ''):gsub('%s*$', '')
  local spaces = 80 - math.min(line_without_tags:len(), 79)
  local new_line = string.format('%s%s%s', line_without_tags, string.rep(' ', spaces), tags):gsub('%s*$', '')
  return vim.fn.setline( headline.range.start_line, new_line)
end

---@return string|nil
function OrgMappings:_get_link_under_cursor()
  local found_link = nil
  local links = {}
  local line = vim.fn.getline('.')
  local col = vim.fn.col('.')
  for link in line:gmatch('%[%[(.-)%]%]') do
    local start_from = #links > 0 and links[#links].to or nil
    local from, to = line:find('%[%[(.-)%]%]', start_from)
    if col >= from and col <= to then
      found_link = link
      break
    end
    table.insert(links, { link = link, from = from, to = to })
  end
  return found_link
end

function _G.orgmode.autocomplete_set_tags(arg_lead)
  return Files.autocomplete_tags(arg_lead)
end

return OrgMappings

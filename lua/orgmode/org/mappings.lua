local Calendar = require('orgmode.objects.calendar')
local Date = require('orgmode.objects.date')
local EditSpecial = require('orgmode.objects.edit_special')
local Files = require('orgmode.parser.files')
local Help = require('orgmode.objects.help')
local Hyperlinks = require('orgmode.org.hyperlinks')
local PriorityState = require('orgmode.objects.priority_state')
local TodoState = require('orgmode.objects.todo_state')
local config = require('orgmode.config')
local constants = require('orgmode.utils.constants')
local ts_utils = require('nvim-treesitter.ts_utils')
local utils = require('orgmode.utils')
local ts_org = require('orgmode.treesitter')
local ts_table = require('orgmode.treesitter.table')

---@class OrgMappings
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
  local archive_location = file:get_archive_file_location()
  local archive_directory = vim.fn.fnamemodify(archive_location, ':p:h')
  if vim.fn.isdirectory(archive_directory) == 0 then
    vim.fn.mkdir(archive_directory, 'p')
  end
  self.capture:refile_file_headline_to_archive(file, item, archive_location)
  Files.reload(
    archive_location,
    vim.schedule_wrap(function()
      Files.update_file(archive_location, function(archive_file)
        local last_item = archive_file:get_closest_headline(vim.fn.line('$'))
        if not last_item then
          return
        end
        last_item:add_properties({
          ARCHIVE_TIME = Date.now():to_string(),
          ARCHIVE_FILE = file.filename,
          ARCHIVE_CATEGORY = item.category,
          ARCHIVE_TODO = item.todo_keyword.value,
        })
      end)
    end)
  )
end

---@param tags? string|string[]
function OrgMappings:set_tags(tags)
  local headline = ts_org.closest_headline()
  local _, current_tags = headline:tags()

  if not tags then
    tags = vim.fn.OrgmodeInput('Tags: ', current_tags, Files.autocomplete_tags)
  elseif type(tags) == 'table' then
    tags = string.format(':%s:', table.concat(tags, ':'))
  end

  return headline:set_tags(tags)
end

function OrgMappings:toggle_archive_tag()
  local headline = ts_org.closest_headline()
  local _, current_tags = headline:tags()

  local parsed = utils.parse_tags_string(current_tags)
  if vim.tbl_contains(parsed, 'ARCHIVE') then
    parsed = vim.tbl_filter(function(tag)
      return tag ~= 'ARCHIVE'
    end, parsed)
  else
    table.insert(parsed, 'ARCHIVE')
  end

  return headline:set_tags(utils.tags_to_string(parsed))
end

function OrgMappings:cycle()
  local file = Files.get_current_file()
  local line = vim.fn.line('.')
  if not vim.wo.foldenable then
    vim.wo.foldenable = true
    vim.cmd([[silent! norm!zx]])
  end
  local level = vim.fn.foldlevel(line)
  if level == 0 then
    return utils.echo_info('No fold')
  end
  local is_fold_closed = vim.fn.foldclosed(line) ~= -1
  if is_fold_closed then
    return vim.cmd([[silent! norm!zo]])
  end
  local section = file.sections_by_line[line]
  if section then
    if not section:has_children() then
      return
    end
    local close = #section.sections == 0
    if not close then
      local has_nested_children = false
      for _, child in ipairs(section.sections) do
        if not has_nested_children and child:has_children() then
          has_nested_children = true
        end
        if child:has_children() and vim.fn.foldclosed(child.line_number) == -1 then
          vim.cmd(string.format('silent! keepjumps norm!%dggzc', child.line_number))
          close = true
        end
      end
      vim.cmd(string.format('silent! keepjumps norm!%dgg', line))
      if not close and not has_nested_children then
        close = true
      end
    end

    if close then
      return vim.cmd([[silent! norm!zc]])
    end
    return vim.cmd([[silent! norm!zczO]])
  end

  if vim.fn.getline(line):match('^%s*:[^:]*:%s*$') then
    return vim.cmd([[silent! norm!za]])
  end
end

function OrgMappings:global_cycle()
  if not vim.wo.foldenable or self.global_cycle_mode == 'Show All' then
    self.global_cycle_mode = 'Overview'
    utils.echo_info(self.global_cycle_mode)
    return vim.cmd([[silent! norm!zMzX]])
  end
  if self.global_cycle_mode == 'Contents' then
    self.global_cycle_mode = 'Show All'
    utils.echo_info(self.global_cycle_mode)
    return vim.cmd([[silent! norm!zR]])
  end
  self.global_cycle_mode = 'Contents'
  utils.echo_info(self.global_cycle_mode)
  vim.wo.foldlevel = 1
  return vim.cmd([[silent! norm!zx]])
end

function OrgMappings:toggle_checkbox()
  local win_view = vim.fn.winsaveview()
  -- move to the first non-blank character so the current treesitter node is the listitem
  vim.cmd([[normal! _]])

  local listitem = ts_org.listitem()
  if listitem then
    listitem:update_checkbox('toggle')
  end

  vim.fn.winrestview(win_view)
end

function OrgMappings:timestamp_up_day()
  return self:_adjust_date(vim.v.count1, 'd', config.mappings.org.org_timestamp_up_day)
end

function OrgMappings:timestamp_down_day()
  return self:_adjust_date(-vim.v.count1, 'd', config.mappings.org.org_timestamp_down_day)
end

function OrgMappings:timestamp_up()
  return self:_adjust_date_part('+', vim.v.count1, config.mappings.org.org_timestamp_up)
end

function OrgMappings:timestamp_down()
  return self:_adjust_date_part('-', vim.v.count1, config.mappings.org.org_timestamp_down)
end

function OrgMappings:_adjust_date_part(direction, amount, fallback)
  local date_on_cursor = self:_get_date_under_cursor()
  local get_adj = function(span, count)
    return string.format('%d%s', count or amount, span)
  end
  local minute_adj = get_adj('M', tonumber(config.org_time_stamp_rounding_minutes) * amount)
  local do_replacement = function(date)
    local col = vim.fn.col('.')
    local char = vim.fn.getline('.'):sub(col, col)
    local raw_date_value = vim.fn.getline('.'):sub(date.range.start_col + 1, date.range.end_col - 1)
    if col == date.range.start_col or col == date.range.end_col then
      date.active = not date.active
      return self:_replace_date(date)
    end
    local col_from_start = col - date.range.start_col
    local parts = Date.parse_parts(raw_date_value)
    local adj = nil
    local modify_end_time = false
    local part = nil
    for _, p in ipairs(parts) do
      if col_from_start >= p.from and col_from_start <= p.to then
        part = p
        break
      end
    end

    if not part then
      return
    end

    local offset = col_from_start - part.from

    if part.type == 'date' then
      if offset <= 4 then
        adj = get_adj('y')
      elseif offset <= 7 then
        adj = get_adj('m')
      else
        adj = get_adj('d')
      end
    end

    if part.type == 'dayname' then
      adj = get_adj('d')
    end

    if part.type == 'time' then
      if offset <= 2 then
        adj = get_adj('h')
      else
        adj = minute_adj
      end
    end

    if part.type == 'time_range' then
      if offset <= 2 then
        adj = get_adj('h')
      elseif offset <= 5 then
        adj = minute_adj
      elseif offset <= 8 then
        adj = get_adj('h')
        modify_end_time = true
      else
        adj = minute_adj
        modify_end_time = true
      end
    end

    if part.type == 'adjustment' then
      local map = { h = 'd', d = 'w', w = 'm', m = 'y', y = 'h' }
      if map[char] then
        vim.cmd(string.format('norm!r%s', map[char]))
      end
      return true
    end

    if not adj then
      return false
    end

    local new_date = nil
    if modify_end_time then
      new_date = date:adjust_end_time(direction .. adj)
    else
      new_date = date:adjust(direction .. adj)
    end

    self:_replace_date(new_date)

    if date:is_logbook() and date.related_date_range then
      local item = Files.get_closest_headline()
      if item and item.logbook then
        item.logbook:recalculate_estimate(new_date.range.start_line)
      end
    end
    return true
  end

  if date_on_cursor then
    local replaced = do_replacement(date_on_cursor)
    if replaced then
      return true
    end
  end

  return vim.api.nvim_feedkeys(utils.esc(fallback), 'n', true)
end

function OrgMappings:change_date()
  local date = self:_get_date_under_cursor()
  if not date then
    return
  end
  return Calendar.new({ date = date }).open():next(function(new_date)
    if new_date then
      self:_replace_date(new_date)
    end
  end)
end

function OrgMappings:priority_up()
  self:set_priority('up')
end

function OrgMappings:priority_down()
  self:set_priority('down')
end

function OrgMappings:set_priority(direction)
  local headline = ts_org.closest_headline()
  local _, current_priority = headline:priority()
  local priority_state = PriorityState:new(current_priority)

  local new_priority = direction
  if direction == 'up' then
    new_priority = priority_state:increase()
  elseif direction == 'down' then
    new_priority = priority_state:decrease()
  elseif direction == nil then
    new_priority = priority_state:prompt_user()
    if new_priority == nil then
      return
    end
  end

  headline:set_priority(new_priority)
end

function OrgMappings:todo_next_state()
  return self:_todo_change_state('next')
end

function OrgMappings:todo_prev_state()
  self:_todo_change_state('prev')
end

function OrgMappings:toggle_heading()
  local line = vim.fn.getline('.')
  local parent = Files.get_closest_headline()
  if not parent then
    line = '* ' .. line
    vim.fn.setline('.', line)
    return
  end

  if parent.line_number == vim.api.nvim_win_get_cursor(0)[1] then
    line = line:gsub('^%*+%s', '')
  else
    line = line:gsub('^(%s*)', '')
    if line:match('^[%*-]%s') then -- handle lists
      line = line:gsub('^[%*-]%s', '') -- strip bullet
      line = line:gsub('^%[([X%s])%]%s', function(checkbox_state)
        if checkbox_state == 'X' then
          return config:get_todo_keywords().DONE[1] .. ' '
        else
          return config:get_todo_keywords().TODO[1] .. ' '
        end
      end)
    end

    line = string.rep('*', parent.level + 1) .. ' ' .. line
  end

  vim.fn.setline('.', line)
end

function OrgMappings:_todo_change_state(direction)
  local headline = ts_org.closest_headline()
  local _, old_state, was_done = headline:todo()
  local changed = self:_change_todo_state(direction, true)
  if not changed then
    return
  end
  local item = Files.get_closest_headline()
  if not item:is_done() and not was_done then
    return item
  end

  local repeater_dates = item:get_repeater_dates()
  if #repeater_dates == 0 then
    local log_time = config.org_log_done == 'time'
    if log_time and item:is_done() and not was_done then
      headline:add_closed_date()
    end
    if log_time and not item:is_done() and was_done then
      headline:remove_closed_date()
    end
    return item
  end

  for _, date in ipairs(repeater_dates) do
    self:_replace_date(date:apply_repeater())
  end

  self:_change_todo_state('reset')
  local state_change =
    string.format('- State "%s" from "%s" [%s]', item.todo_keyword.value, old_state, Date.now():to_string())

  local data = item:add_properties({ LAST_REPEAT = '[' .. Date.now():to_string() .. ']' })
  if data.is_new then
    vim.fn.append(data.end_line, data.indent .. state_change)
    return item
  end
  item = Files.get_closest_headline()

  if item.properties.valid then
    vim.fn.append(item.properties.range.end_line, data.indent .. state_change)
  end
end

function OrgMappings:do_promote(whole_subtree)
  local item = Files.get_closest_headline()
  local foldclosed = vim.fn.foldclosed('.')
  item:promote(1, whole_subtree)
  if foldclosed > -1 and vim.fn.foldclosed('.') == -1 then
    vim.cmd([[norm!zc]])
  end
end

function OrgMappings:do_demote(whole_subtree)
  local item = Files.get_closest_headline()
  local foldclosed = vim.fn.foldclosed('.')
  item:demote(1, whole_subtree)
  if foldclosed > -1 and vim.fn.foldclosed('.') == -1 then
    vim.cmd([[norm!zc]])
  end
end

function OrgMappings:org_return()
  local actions = {
    ts_table.handle_cr,
  }

  for _, action in ipairs(actions) do
    local handled = action()
    if handled then
      return
    end
  end

  local old_mapping = config.old_cr_mapping

  if not old_mapping or vim.tbl_isempty(old_mapping) then
    return vim.api.nvim_feedkeys(utils.esc('<CR>'), 'n', true)
  end

  local rhs = old_mapping.rhs

  if old_mapping.expr > 0 then
    rhs = vim.api.nvim_eval(rhs)
  end

  if old_mapping.script > 0 then
    rhs = rhs:gsub('<SID>', string.format('<SNR>%d_', old_mapping.sid))
    if rhs:match('^<CR>') then
      rhs = rhs:gsub('<CR>', '')
      vim.api.nvim_feedkeys(utils.esc('<CR>'), 'n', true)
    end

    if rhs:match('^' .. utils.esc('<CR>')) then
      rhs = rhs:gsub('^' .. utils.esc('<CR>'), '')
      vim.api.nvim_feedkeys(utils.esc('<CR>'), 'n', true)
    end

    if old_mapping.expr > 0 and rhs:match('^' .. utils.esc('<c-r>') .. '=') then
      rhs = rhs:gsub('^' .. utils.esc('<c-r>') .. '=', ''):gsub(utils.esc('<CR>') .. '$', '')
      rhs = vim.api.nvim_eval(rhs)
    end

    return vim.api.nvim_feedkeys(utils.esc(rhs), '', true)
  end

  return vim.api.nvim_feedkeys(utils.esc(rhs), 'n', true)
end

function OrgMappings:handle_return(suffix)
  suffix = suffix or ''
  local current_file = Files.get_current_file()
  local item = current_file:get_current_node()
  if item.type == 'expr' then
    item = current_file:convert_to_file_node(item.node:parent())
  end

  if item.node:parent() and item.node:parent():type() == 'headline' then
    item = current_file:convert_to_file_node(item.node:parent())
  end

  if item.type == 'headline' then
    local linenr = vim.fn.line('.')
    local content = config:respect_blank_before_new_entry({ string.rep('*', item.level) .. ' ' .. suffix })
    vim.fn.append(linenr, content)
    vim.fn.cursor(linenr + #content, 0)
    return vim.cmd([[startinsert!]])
  end

  if item.type == 'list' or item.type == 'listitem' then
    vim.cmd([[normal! ^]])
    item = Files.get_current_file():get_current_node()
  end

  if item.type == 'paragraph' or item.type == 'bullet' then
    local listitem = item.node:parent()
    if listitem:type() ~= 'listitem' then
      return
    end
    local line = vim.fn.getline(listitem:start() + 1)
    local end_row, _ = listitem:end_()
    local next_line_node = current_file:get_node_at_cursor({ end_row + 1, 0 })
    local second_line_node = current_file:get_node_at_cursor({ end_row + 2, 0 })
    local is_end_of_file = next_line_node
      and vim.tbl_contains({ 'paragraph', 'list' }, next_line_node:type())
      and second_line_node
      and second_line_node:type() == 'document'
    -- Range for list items at the very end of the file are not calculated properly
    if (end_row + 1) == vim.fn.line('$') and is_end_of_file then
      end_row = end_row + 1
    end
    local range = {
      start = { line = end_row, character = 0 },
      ['end'] = { line = end_row, character = 0 },
    }

    local checkbox = line:match('^(%s*[%+%-])%s*%[[%sXx%-]?%]')
    local plain_list = line:match('^%s*[%+%-]')
    local indent, number_in_list, closer = line:match('^(%s*)(%d+)([%)%.])%s?')
    local text_edits = config:respect_blank_before_new_entry({}, 'plain_list_item', {
      range = range,
      newText = '\n',
    })
    local add_empty_line = #text_edits > 0
    if checkbox then
      table.insert(text_edits, {
        range = range,
        newText = checkbox .. ' [ ] \n',
      })
    elseif plain_list then
      table.insert(text_edits, {
        range = range,
        newText = plain_list .. ' \n',
      })
    elseif number_in_list then
      local next_sibling = listitem
      local counter = 1
      while next_sibling do
        local bullet = next_sibling:child(0)
        local text = vim.treesitter.query.get_node_text(bullet, 0)
        local new_text = tostring(tonumber(text:match('%d+')) + 1) .. closer

        if counter == 1 then
          table.insert(text_edits, {
            range = range,
            newText = indent .. new_text .. ' ' .. '\n',
          })
        else
          table.insert(text_edits, {
            range = ts_utils.node_to_lsp_range(bullet),
            newText = new_text,
          })
        end

        counter = counter + 1
        next_sibling = ts_utils.get_next_node(next_sibling)
      end
    end

    if #text_edits > 0 then
      vim.lsp.util.apply_text_edits(text_edits, 0, constants.default_offset_encoding)

      vim.fn.cursor(end_row + 1 + (add_empty_line and 1 or 0), 0) -- +1 for next line

      -- update all parents when we insert a new checkbox
      if checkbox then
        local new_listitem = ts_org.listitem()
        if new_listitem then
          new_listitem:update_checkbox('off')
        end
      end

      vim.cmd([[startinsert!]])
    end
  end
end

function OrgMappings:insert_heading_respect_content(suffix)
  suffix = suffix or ''
  local item = Files.get_closest_headline()
  local line = config:respect_blank_before_new_entry({ string.rep('*', item.level) .. ' ' .. suffix })
  vim.fn.append(item.range.end_line, line)
  vim.fn.cursor(item.range.end_line + #line, 0)
  return vim.cmd([[startinsert!]])
end

function OrgMappings:insert_todo_heading_respect_content()
  return self:insert_heading_respect_content(config:get_todo_keywords().TODO[1] .. ' ')
end

function OrgMappings:insert_todo_heading()
  local item = Files.get_closest_headline()
  vim.fn.cursor(item.range.start_line, 0)
  return self:handle_return(config:get_todo_keywords().TODO[1] .. ' ')
end

function OrgMappings:move_subtree_up()
  local item = Files.get_closest_headline()
  local prev_headline = item:get_prev_headline_same_level()
  if not prev_headline then
    return utils.echo_warning('Cannot move past superior level.')
  end
  vim.cmd(
    string.format(':%d,%dmove %d', item.range.start_line, item.range.end_line, prev_headline.range.start_line - 1)
  )
end

function OrgMappings:move_subtree_down()
  local item = Files.get_closest_headline()
  local next_headline = item:get_next_headline_same_level()
  if not next_headline then
    return utils.echo_warning('Cannot move past superior level.')
  end
  vim.cmd(string.format(':%d,%dmove %d', item.range.start_line, item.range.end_line, next_headline.range.end_line))
end

function OrgMappings:show_help()
  return Help.show()
end

function OrgMappings:edit_special()
  local edit_special = EditSpecial:new()
  edit_special:init_in_org_buffer()
  edit_special:init()
end

function OrgMappings:_edit_special_callback()
  EditSpecial:new():done()
end

function OrgMappings:open_at_point()
  local date = self:_get_date_under_cursor()
  if date then
    return self.agenda:open_day(date)
  end

  local link = self:_get_link_under_cursor()
  if not link then
    return
  end
  local parts = vim.split(link, '][', true)
  local url = parts[1]
  local link_ctx = { base = url, skip_add_prefix = true }
  if url:find('^file:') then
    if url:find(' +', 1, true) then
      parts = vim.split(url, ' +', true)
      url = parts[1]
      local line_number = parts[2]
      vim.cmd(string.format('edit +%s %s', line_number, url:sub(6)))
      vim.cmd([[normal! zv]])
      return
    end

    if url:find('^file:(.-)::') then
      link_ctx.line = url
    else
      vim.cmd(string.format('edit %s', url:sub(6)))
      vim.cmd([[normal! zv]])
      return
    end
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

  local current_headline = Files.get_closest_headline()
  local headlines = vim.tbl_filter(function(headline)
    return headline.line ~= current_headline.line and headline.id ~= current_headline.id
  end, Hyperlinks.find_matching_links(link_ctx))
  if #headlines == 0 then
    return
  end
  local headline = headlines[1]
  if #headlines > 1 then
    local longest_headline = utils.reduce(headlines, function(acc, h)
      return math.max(acc, h.line:len())
    end, 0)
    local options = {}
    for i, h in ipairs(headlines) do
      table.insert(options, string.format('%d) %-' .. longest_headline .. 's (%s)', i, h.line, h.file))
    end
    vim.cmd([[echo "Multiple targets found. Select target:"]])
    local choice = vim.fn.inputlist(options)
    if choice < 1 or choice > #headlines then
      return
    end
    headline = headlines[choice]
  end
  vim.cmd(string.format('edit %s', headline.file))
  vim.fn.cursor(headline.range.start_line, 0)
end

function OrgMappings:export()
  return require('orgmode.export').prompt()
end

function OrgMappings:next_visible_heading()
  return vim.fn.search([[^\*\+]], 'W')
end

function OrgMappings:previous_visible_heading()
  return vim.fn.search([[^\*\+]], 'bW')
end

function OrgMappings:forward_heading_same_level()
  local item = Files.get_closest_headline()
  if not item then
    return
  end
  local next_headline_same_level = item:get_next_headline_same_level()
  if not next_headline_same_level then
    return
  end
  return vim.fn.cursor(next_headline_same_level.range.start_line, 1)
end

function OrgMappings:backward_heading_same_level()
  local item = Files.get_closest_headline()
  if not item then
    return
  end
  local prev_headline_same_level = item:get_prev_headline_same_level()
  if not prev_headline_same_level then
    return
  end
  return vim.fn.cursor(prev_headline_same_level.range.start_line, 1)
end

function OrgMappings:outline_up_heading()
  local item = Files.get_closest_headline()
  if not item then
    return
  end
  if item.level <= 1 then
    return utils.echo_info('Already at top level of the outline')
  end
  return vim.fn.cursor(item.parent.range.start_line, 1)
end

function OrgMappings:org_deadline()
  local headline = ts_org.closest_headline()
  local deadline_date = headline:deadline()
  return Calendar.new({ date = deadline_date or Date.today() }).open():next(function(new_date)
    if not new_date then
      return
    end
    headline:remove_closed_date()
    headline:set_deadline_date(new_date)
  end)
end

function OrgMappings:org_schedule()
  local headline = ts_org.closest_headline()
  local scheduled_date = headline:scheduled()
  return Calendar.new({ date = scheduled_date or Date.today() }).open():next(function(new_date)
    if not new_date then
      return
    end
    headline:remove_closed_date()
    headline:set_scheduled_date(new_date)
  end)
end

---@param inactive boolean
function OrgMappings:org_time_stamp(inactive)
  local date = self:_get_date_under_cursor()
  if date then
    return Calendar.new({ date = date }).open():next(function(new_date)
      if not new_date then
        return
      end
      self:_replace_date(new_date)
    end)
  end

  local date_start = self:_get_date_under_cursor(-1)

  return Calendar.new({ date = Date.today() }).open():next(function(new_date)
    if not new_date then
      return
    end
    local date_string = new_date:to_wrapped_string(not inactive)
    if date_start then
      date_string = '--' .. date_string
    end
    vim.cmd(string.format('norm!i%s', date_string))
  end)
end

---@param direction string
---@param use_fast_access? boolean
---@return string
function OrgMappings:_change_todo_state(direction, use_fast_access)
  local headline = ts_org.closest_headline()
  local todo, current_keyword = headline:todo()
  local todo_state = TodoState:new({ current_state = current_keyword })
  local next_state = nil
  if use_fast_access and todo_state:has_fast_access() then
    next_state = todo_state:open_fast_access()
  else
    if direction == 'next' then
      next_state = todo_state:get_next()
    elseif direction == 'prev' then
      next_state = todo_state:get_prev()
    elseif direction == 'reset' then
      next_state = todo_state:get_todo()
    end
  end

  if not next_state then
    return false
  end

  if next_state.value == current_keyword then
    if todo.value ~= '' then
      utils.echo_info('TODO state was already ', { { next_state.value, next_state.hl } })
    end
    return false
  end

  headline:set_todo(next_state.value)
  return true
end

---@param date Date
function OrgMappings:_replace_date(date)
  local line = vim.fn.getline(date.range.start_line)
  local view = vim.fn.winsaveview()
  vim.fn.setline(
    date.range.start_line,
    string.format(
      '%s%s%s',
      line:sub(1, date.range.start_col - 1),
      date:to_wrapped_string(),
      line:sub(date.range.end_col + 1)
    )
  )
  vim.fn.winrestview(view)
  return true
end

---@return Date|nil
function OrgMappings:_get_date_under_cursor(col_offset)
  col_offset = col_offset or 0
  local col = vim.fn.col('.') + col_offset
  local line = vim.fn.line('.')
  local item = Files.get_closest_headline()
  local dates = {}
  if item then
    dates = vim.tbl_filter(function(date)
      return date.range:is_in_range(line, col)
    end, item.dates)
  else
    dates = Date.parse_all_from_line(vim.fn.getline('.'), line)
  end

  if #dates == 0 then
    return nil
  end

  return dates[1]
end

---@param amount number
---@param span string
---@param fallback string
---@return string
function OrgMappings:_adjust_date(amount, span, fallback)
  local adjustment = string.format('%s%d%s', amount > 0 and '+' or '', amount, span)
  local date = self:_get_date_under_cursor()
  if date then
    local new_date = date:adjust(adjustment)
    return self:_replace_date(new_date)
  end

  local is_count_mapping = vim.tbl_contains({ '<c-a>', '<c-x>' }, fallback:lower())
  if not is_count_mapping then
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

return OrgMappings

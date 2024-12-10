local Calendar = require('orgmode.objects.calendar')
local Date = require('orgmode.objects.date')
local EditSpecial = require('orgmode.objects.edit_special')
local Help = require('orgmode.objects.help')
local OrgHyperlink = require('orgmode.org.links.hyperlink')
local PriorityState = require('orgmode.objects.priority_state')
local TodoState = require('orgmode.objects.todo_state')
local config = require('orgmode.config')
local constants = require('orgmode.utils.constants')
local ts_utils = require('orgmode.utils.treesitter')
local utils = require('orgmode.utils')
local fs = require('orgmode.utils.fs')
local Table = require('orgmode.files.elements.table')
local EventManager = require('orgmode.events')
local events = EventManager.event
local Babel = require('orgmode.babel')
local ListItem = require('orgmode.files.elements.listitem')

---@class OrgMappings
---@field capture OrgCapture
---@field agenda OrgAgenda
---@field files OrgFiles
---@field links OrgLinks
local OrgMappings = {}

---@param data table
function OrgMappings:new(data)
  local opts = {}
  opts.global_cycle_mode = 'all'
  opts.capture = data.capture
  opts.agenda = data.agenda
  opts.files = data.files
  opts.links = data.links
  setmetatable(opts, self)
  self.__index = self
  return opts
end

-- TODO:
-- Support archiving to headline
function OrgMappings:archive()
  return self.capture:refile_file_headline_to_archive(self.files:get_closest_headline())
end

---@param tags? string|string[]
function OrgMappings:set_tags(tags)
  local headline = self.files:get_closest_headline()
  local current_tags = utils.tags_to_string(headline:get_own_tags())

  if not tags then
    tags = vim.fn.OrgmodeInput('Tags: ', current_tags, function(arg_lead)
      return utils.prompt_autocomplete(arg_lead, self.files:get_tags())
    end)
  elseif type(tags) == 'table' then
    tags = string.format(':%s:', table.concat(tags, ':'))
  end

  return headline:set_tags(tags)
end

function OrgMappings:toggle_archive_tag()
  local headline = self.files:get_closest_headline()
  local current_tags = headline:get_own_tags()

  if vim.tbl_contains(current_tags, 'ARCHIVE') then
    current_tags = vim.tbl_filter(function(tag)
      return tag ~= 'ARCHIVE'
    end, current_tags)
  else
    table.insert(current_tags, 'ARCHIVE')
  end

  return headline:set_tags(utils.tags_to_string(current_tags))
end

function OrgMappings:cycle()
  local file = self.files:get_current_file()
  if not file then
    return
  end
  local line = vim.fn.line('.') or 0
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
  local section = file:get_closest_headline_or_nil({ line, 0 })

  if not section then
    -- Toggle drawers
    if vim.fn.getline(line):match('^%s*:[^:]*:%s*$') then
      vim.cmd([[silent! norm!za]])
    end
    return
  end

  local is_expandable = function(headline)
    return headline:has_child_headlines() or not headline:is_one_line()
  end

  -- Skip one liner
  if not is_expandable(section) then
    return
  end

  local children = section:get_child_headlines()
  local close = #children == 0

  if not close then
    local has_nested_children = false
    for _, child in ipairs(children) do
      local is_child_expandable = is_expandable(child)
      if not has_nested_children and is_child_expandable then
        has_nested_children = true
      end
      local child_range = child:get_range()
      if is_child_expandable and vim.fn.foldclosed(child_range.start_line) == -1 then
        vim.cmd(string.format('silent! keepjumps norm!%dggzc', child_range.start_line))
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

function OrgMappings:org_babel_tangle()
  return Babel.tangle(self.files:get_current_file())
end

function OrgMappings:toggle_checkbox()
  local win_view = vim.fn.winsaveview() or {}
  -- move to the first non-blank character so the current treesitter node is the listitem
  vim.cmd([[normal! _]])

  local listitem = self.files:get_closest_listitem()
  if listitem then
    listitem:update_checkbox('toggle')
  end

  vim.fn.winrestview(win_view)
end

function OrgMappings:timestamp_up_day()
  return self:_adjust_date(vim.v.count1, 'd', vim.v.count1 .. config.mappings.org.org_timestamp_up_day)
end

function OrgMappings:timestamp_down_day()
  return self:_adjust_date(-vim.v.count1, 'd', vim.v.count1 .. config.mappings.org.org_timestamp_down_day)
end

function OrgMappings:timestamp_up()
  return self:_adjust_date_part('+', vim.v.count1, vim.v.count1 .. config.mappings.org.org_timestamp_up)
end

function OrgMappings:timestamp_down()
  return self:_adjust_date_part('-', vim.v.count1, vim.v.count1 .. config.mappings.org.org_timestamp_down)
end

function OrgMappings:_adjust_date_part(direction, amount, fallback)
  local date_on_cursor = self:_get_date_under_cursor()
  local get_adj = function(span, count)
    return string.format('%d%s', count or amount, span)
  end
  local minute_adj = get_adj('M', tonumber(config.org_time_stamp_rounding_minutes) * amount)
  local do_replacement = function(date)
    local col = vim.fn.col('.') or 0
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
      local item = self.files:get_closest_headline_or_nil()
      if item then
        local logbook = item:get_logbook()
        if logbook then
          logbook:recalculate_estimate(new_date.range.start_line)
        end
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
  return Calendar.new({ date = date, title = 'Change date' }):open():next(function(new_date)
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
  local headline = self.files:get_closest_headline()
  local current_priority = headline:get_priority()
  local prio_range = config:get_priority_range()
  local priority_state = PriorityState:new(current_priority, prio_range, config.org_priority_start_cycle_with_default)

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
  -- TODO: allow nil
  local parent = self.files:get_closest_headline_or_nil()
  if not parent then
    line = '* ' .. line
    vim.fn.setline('.', line)
    return
  end

  if parent:get_range().start_line == vim.api.nvim_win_get_cursor(0)[1] then
    line = line:gsub('^%*+%s', '')
  else
    line = line:gsub('^(%s*)', '')
    if line:match('^[%*-]%s') then -- handle lists
      line = line:gsub('^[%*-]%s', '') -- strip bullet
      local todo_keywords = config:get_todo_keywords()
      line = line:gsub('^%[([X%s])%]%s', function(checkbox_state)
        if checkbox_state == 'X' then
          return todo_keywords:first_by_type('DONE').value .. ' '
        else
          return todo_keywords:first_by_type('TODO').value .. ' '
        end
      end)
    end

    line = string.rep('*', parent:get_level() + 1) .. ' ' .. line
  end

  vim.fn.setline('.', line)
end

---Prompt for a note
---@private
---@param template string
---@param indent string
---@param title string
---@return OrgPromise<string[]>
function OrgMappings:_get_note(template, indent, title)
  return self.capture:build_note_capture(title):open():next(function(closing_note)
    if closing_note == nil then
      return
    end

    for i, line in ipairs(closing_note) do
      closing_note[i] = indent .. '  ' .. line
    end

    return vim.list_extend({ template }, closing_note)
  end)
end

function OrgMappings:_todo_change_state(direction)
  local headline = self.files:get_closest_headline()
  local old_state = headline:get_todo()
  local was_done = headline:is_done()
  local changed = self:_change_todo_state(direction, true)

  if not changed then
    return
  end

  local item = self.files:get_closest_headline()
  EventManager.dispatch(events.TodoChanged:new(item, old_state, was_done))

  local is_done = item:is_done() and not was_done
  local is_undone = not item:is_done() and was_done

  -- State was changed in the same group (TODO NEXT | DONE)
  -- For example: Changed from TODO to NEXT
  if not is_done and not is_undone then
    return item
  end

  local prompt_done_note = config.org_log_done == 'note'
  local log_closed_time = config.org_log_done == 'time'
  local indent = headline:get_indent()

  local closing_note_text = ('%s- CLOSING NOTE %s \\\\'):format(indent, Date.now():to_wrapped_string(false))
  local closed_title = 'Insert note for closed todo item'

  local repeater_dates = item:get_repeater_dates()

  -- No dates with a repeater. Add closed date and note if enabled.
  if #repeater_dates == 0 then
    local set_closed_date = prompt_done_note or log_closed_time
    if set_closed_date then
      if is_done then
        headline:set_closed_date()
      elseif is_undone then
        headline:remove_closed_date()
      end
      item = self.files:get_closest_headline()
    end

    if is_undone or not prompt_done_note then
      return item
    end

    return self:_get_note(closing_note_text, indent, closed_title):next(function(closing_note)
      return item:add_note(closing_note)
    end)
  end

  for _, date in ipairs(repeater_dates) do
    self:_replace_date(date:apply_repeater())
  end
  local new_todo = item:get_todo()
  self:_change_todo_state('reset')

  local prompt_repeat_note = config.org_log_repeat == 'note'
  local log_repeat_enabled = config.org_log_repeat ~= false
  local repeat_note_template = ('%s- State %-12s from %-12s [%s]'):format(
    indent,
    [["]] .. new_todo .. [["]],
    [["]] .. old_state .. [["]],
    Date.now():to_string()
  )
  local repeat_note_title = ('Insert note for state change from "%s" to "%s"'):format(old_state, new_todo)

  if log_repeat_enabled then
    item:set_property('LAST_REPEAT', Date.now():to_wrapped_string(false))
  end

  if not prompt_repeat_note and not prompt_done_note then
    -- If user is not prompted for a note, use a default repeat note
    if log_repeat_enabled then
      return item:add_note({ repeat_note_template })
    end
    return item
  end

  -- Done note has precedence over repeat note
  if prompt_done_note then
    return self:_get_note(closing_note_text, indent, closed_title):next(function(closing_note)
      return item:add_note(closing_note)
    end)
  end

  return self:_get_note(repeat_note_template .. ' \\\\', indent, repeat_note_title):next(function(closing_note)
    return item:add_note(closing_note)
  end)
end

function OrgMappings:do_promote(whole_subtree)
  local count = vim.v.count1
  local win_view = vim.fn.winsaveview() or {}
  -- move to the first non-blank character so the current treesitter node is the listitem
  vim.cmd([[normal! _]])

  local node = ts_utils.get_node_at_cursor()
  if node and node:type() == 'bullet' then
    local listitem = self.files:get_closest_listitem()
    if listitem then
      listitem:promote(whole_subtree)
      vim.fn.winrestview(win_view)
      return
    end
  end

  local headline = self.files:get_closest_headline()
  local old_level = headline:get_level()
  local foldclosed = vim.fn.foldclosed('.')
  headline:promote(count, whole_subtree)
  if foldclosed > -1 and vim.fn.foldclosed('.') == -1 then
    vim.cmd([[norm!zc]])
  end
  EventManager.dispatch(events.HeadlinePromoted:new(self.files:get_closest_headline(), old_level))
  vim.fn.winrestview(win_view)
end

function OrgMappings:do_demote(whole_subtree)
  local count = vim.v.count1
  local win_view = vim.fn.winsaveview() or {}
  -- move to the first non-blank character so the current treesitter node is the listitem
  vim.cmd([[normal! _]])

  local node = ts_utils.get_node_at_cursor()
  if node and node:type() == 'bullet' then
    local listitem = self.files:get_closest_listitem()
    if listitem then
      listitem:demote(whole_subtree)
      vim.fn.winrestview(win_view)

      return
    end
  end

  local headline = self.files:get_closest_headline()
  local old_level = headline:get_level()
  local foldclosed = vim.fn.foldclosed('.')
  headline:demote(count, whole_subtree)
  if foldclosed > -1 and vim.fn.foldclosed('.') == -1 then
    vim.cmd([[norm!zc]])
  end
  EventManager.dispatch(events.HeadlineDemoted:new(self.files:get_closest_headline(), old_level))
  vim.fn.winrestview(win_view)
end

function OrgMappings:org_return()
  local actions = {
    function()
      local tbl = Table.from_current_node()
      return tbl and tbl:handle_cr() or false
    end,
    function()
      if not config.mappings.org_return_uses_meta_return then
        return false
      end

      if vim.trim(vim.fn.getline('.'):sub(vim.fn.col('.'), vim.fn.col('$'))) ~= '' then
        return false
      end

      return self:meta_return()
    end,
  }

  for _, action in ipairs(actions) do
    local handled = action()
    if handled then
      return
    end
  end

  local old_mapping = vim.b.org_old_cr_mapping

  -- No other mapping for <CR>, just reproduce it.
  if not old_mapping or vim.tbl_isempty(old_mapping) then
    return vim.api.nvim_feedkeys(utils.esc('<CR>'), 'n', true)
  end

  local rhs = old_mapping.rhs
  local eval = old_mapping.expr > 0

  if old_mapping.callback then
    rhs = old_mapping.callback()
    eval = false
  end

  if eval then
    rhs = vim.api.nvim_eval(rhs)
  end

  -- If the rhs is empty, assume that callback already handled the action
  if old_mapping.callback and not rhs then
    return
  end

  return vim.api.nvim_feedkeys(rhs, 'n', true)
end

function OrgMappings:handle_return(suffix)
  vim.deprecate('org_mappings.handle_return', 'org_mappings.meta_return', '0.4', 'orgmode', false)
  return self:meta_return(suffix)
end

function OrgMappings:meta_return(suffix)
  suffix = suffix or ''
  local item = ts_utils.get_node_at_cursor()

  if not item then
    return
  end

  if item:type() == 'expr' then
    item = item:parent()
  end

  if item and item:parent() and item:parent():type() == 'headline' then
    item = item:parent()
  end

  if not item then
    return
  end

  if item:type() == 'headline' then
    local linenr = vim.fn.line('.') or 0
    local _, level = item:field('stars')[1]:end_()
    local content = config:respect_blank_before_new_entry({ ('*'):rep(level) .. ' ' .. suffix })
    vim.fn.append(linenr, content)
    vim.fn.cursor(linenr + #content, 1)
    vim.cmd([[startinsert!]])
    return true
  end

  if item:type() == 'list' or item:type() == 'listitem' then
    vim.cmd([[normal! ^]])
    item = ts_utils.get_node_at_cursor()
  end
  if not item then
    return
  end
  local type = item:type()
  if vim.tbl_contains({ 'paragraph', 'bullet', 'checkbox', 'status' }, type) then
    local listitem = item:parent()
    if not listitem or listitem:type() ~= 'listitem' then
      return
    end
    local line = vim.fn.getline(listitem:start() + 1)
    local srow, _, end_row, end_col = listitem:range()
    local is_multiline = (end_row - srow) > 1 or end_col == 0
    -- For last item in file, ts grammar is not parsing the end column as 0
    -- while in other cases end column is always 0
    local is_last_item_in_file = end_col ~= 0
    if not is_multiline or is_last_item_in_file then
      end_row = end_row + 1
    end
    local range = {
      start = { line = end_row, character = 0 },
      ['end'] = { line = end_row, character = 0 },
    }

    local checkbox = line:match('^(%s*[%+%-%*])%s*%[[%sXx%-]?%]')
    local plain_list = line:match('^%s*[%+%-%*]')
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
        local text = bullet and vim.treesitter.get_node_text(bullet, 0) or ''
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
        next_sibling = next_sibling:next_sibling()
      end
    end

    if #text_edits > 0 then
      vim.lsp.util.apply_text_edits(text_edits, vim.api.nvim_get_current_buf(), constants.default_offset_encoding)

      vim.fn.cursor(end_row + 1 + (add_empty_line and 1 or 0), 1) -- +1 for next line

      -- update all parents when we insert a new checkbox
      if checkbox then
        local new_listitem = self.files:get_closest_listitem()
        if new_listitem then
          new_listitem:update_checkbox('off')
        end
      end

      vim.cmd([[startinsert!]])
      return true
    end
  end
end

function OrgMappings:insert_heading_respect_content(suffix)
  suffix = suffix or ''
  local item = self.files:get_closest_headline_or_nil()
  if not item then
    self:_insert_heading_from_plain_line(suffix)
  else
    local line = config:respect_blank_before_new_entry({ string.rep('*', item:get_level()) .. ' ' .. suffix })
    local end_line = item:get_range().end_line
    vim.fn.append(end_line, line)
    vim.fn.cursor(end_line + #line, 1)
  end
  return vim.cmd([[startinsert!]])
end

function OrgMappings:insert_todo_heading_respect_content()
  return self:insert_heading_respect_content(config:get_todo_keywords():first_by_type('TODO').value .. ' ')
end

function OrgMappings:insert_todo_heading()
  local item = self.files:get_closest_headline_or_nil()
  local first_todo_keyword = config:get_todo_keywords():first_by_type('TODO')
  if not item then
    self:_insert_heading_from_plain_line(first_todo_keyword.value .. ' ')
    return vim.cmd([[startinsert!]])
  else
    vim.fn.cursor(item:get_range().start_line, 1)
    return self:meta_return(first_todo_keyword.value .. ' ')
  end
end

function OrgMappings:_insert_heading_from_plain_line(suffix)
  suffix = suffix or ''
  local linenr = vim.fn.line('.') or 0
  local line = vim.fn.getline(linenr)
  local heading_prefix = '* ' .. suffix

  if #line == 0 then
    line = heading_prefix
    vim.fn.setline(linenr, line)
    vim.fn.cursor(linenr, 0 + #line)
  else
    if vim.fn.col('.') == 1 then
      -- promote whole line to heading
      line = heading_prefix .. line
      vim.fn.setline(linenr, line)
      vim.fn.cursor(linenr, 0 + #line)
    else
      -- split at cursor
      local left = string.sub(line, 0, vim.fn.col('.') - 1)
      local right = string.sub(line, vim.fn.col('.') or 0, #line)
      line = heading_prefix .. right
      vim.fn.setline(linenr, left)
      vim.fn.append(linenr, line)
      vim.fn.cursor(linenr + 1, 0 + #line)
    end
  end
end

-- Inserts a new link after the cursor position or modifies the link the cursor is
-- currently on
function OrgMappings:insert_link()
  local link_location = vim.fn.OrgmodeInput('Links: ', '', function(arg_lead)
    return self.links:autocomplete(arg_lead)
  end)
  if vim.trim(link_location) == '' then
    utils.echo_warning('No Link selected')
    return
  end

  self.links:insert_link(link_location)
end

function OrgMappings:store_link()
  local headline = self.files:get_closest_headline()
  self.links:store_link_to_headline(headline)
  return utils.echo_info('Stored: ' .. headline:get_title())
end

function OrgMappings:move_subtree_up()
  local item = self.files:get_closest_headline()
  local prev_headline = item:get_prev_headline_same_level()
  if not prev_headline then
    return utils.echo_warning('Cannot move past superior level.')
  end
  local range = item:get_range()
  local target_line = prev_headline:get_range().start_line - 1
  local foldclosed = vim.fn.foldclosed('.')
  vim.cmd(string.format(':%d,%dmove %d', range.start_line, range.end_line, target_line))
  local pos = vim.fn.getcurpos()
  vim.fn.cursor(target_line + 1, pos[2])
  if foldclosed > -1 and vim.fn.foldclosed('.') == -1 then
    vim.cmd([[norm!zc]])
  end
end

function OrgMappings:move_subtree_down()
  local item = self.files:get_closest_headline()
  local next_headline = item:get_next_headline_same_level()
  if not next_headline then
    return utils.echo_warning('Cannot move past superior level.')
  end
  local range = item:get_range()
  local target_line = next_headline:get_range().end_line
  local foldclosed = vim.fn.foldclosed('.')
  vim.cmd(string.format(':%d,%dmove %d', range.start_line, range.end_line, target_line))
  local pos = vim.fn.getcurpos()
  vim.fn.cursor(target_line + range.start_line - range.end_line, pos[2])
  if foldclosed > -1 and vim.fn.foldclosed('.') == -1 then
    vim.cmd([[norm!zc]])
  end
end

function OrgMappings:show_help(type)
  return Help.show(type)
end

function OrgMappings:edit_special()
  local edit_special = EditSpecial:new()
  edit_special:init_in_org_buffer()
  edit_special:init()
end

function OrgMappings:_edit_special_callback()
  EditSpecial:new():done()
end

function OrgMappings:add_note()
  local headline = self.files:get_closest_headline()
  local indent = headline:get_indent()
  local text = ('%s- Note taken on %s \\\\'):format(indent, Date.now():to_wrapped_string(false))
  return self:_get_note(text, indent, 'Insert note for entry.'):next(function(note)
    if not note then
      return false
    end
    return headline:add_note(note)
  end)
end

function OrgMappings:open_at_point()
  local link = OrgHyperlink.at_cursor()
  if not link then
    local date = self:_get_date_under_cursor()
    if date then
      return self.agenda:open_day(date)
    end
    return
  end

  return self.links:follow(link.url:to_string())
end

function OrgMappings:export()
  return require('orgmode.export').prompt()
end

---Find and move cursor to next visible heading.
---@return integer
function OrgMappings:next_visible_heading()
  return vim.fn.search([[^\*\+]], 'W', 0, 0, self._skip_invisible_heading)
end

---Find and move cursor to previous visible heading.
---@return integer
function OrgMappings:previous_visible_heading()
  return vim.fn.search([[^\*\+]], 'bW', 0, 0, self._skip_invisible_heading)
end

---Check if heading is visible. If not, skip it.
---@return integer
function OrgMappings:_skip_invisible_heading()
  local fold = vim.fn.foldclosed('.')
  if fold == -1 or vim.fn.line('.') == fold then
    return 0
  end
  return 1
end

function OrgMappings:forward_heading_same_level()
  local item = self.files:get_closest_headline()
  local next_headline_same_level = item:get_next_headline_same_level()
  if not next_headline_same_level then
    return
  end
  return vim.fn.cursor(next_headline_same_level:get_range().start_line, 1)
end

function OrgMappings:backward_heading_same_level()
  local item = self.files:get_closest_headline()
  local prev_headline_same_level = item:get_prev_headline_same_level()
  if not prev_headline_same_level then
    return
  end
  return vim.fn.cursor(prev_headline_same_level:get_range().start_line, 1)
end

function OrgMappings:outline_up_heading()
  local item = self.files:get_closest_headline()
  local parent = item:get_parent_headline()
  if not parent then
    return utils.echo_info('Already at top level of the outline')
  end
  return vim.fn.cursor(parent:get_range().start_line, 1)
end

function OrgMappings:org_deadline()
  local headline = self.files:get_closest_headline()
  local deadline_date = headline:get_deadline_date()
  return Calendar.new({ date = deadline_date or Date.today(), clearable = true, title = 'Set deadline' })
    :open()
    :next(function(new_date, cleared)
      if cleared then
        return headline:remove_deadline_date()
      end
      if not new_date then
        return nil
      end
      headline:remove_closed_date()
      headline:set_deadline_date(new_date)
    end)
end

function OrgMappings:org_schedule()
  local headline = self.files:get_closest_headline()
  local scheduled_date = headline:get_scheduled_date()
  return Calendar.new({ date = scheduled_date or Date.today(), clearable = true, title = 'Set schedule' })
    :open()
    :next(function(new_date, cleared)
      if cleared then
        return headline:remove_scheduled_date()
      end
      if not new_date then
        return nil
      end
      headline:remove_closed_date()
      headline:set_scheduled_date(new_date)
    end)
end

---@param inactive boolean
function OrgMappings:org_time_stamp(inactive)
  local date = self:_get_date_under_cursor()

  if date then
    return Calendar.new({ date = date, title = 'Replace date' }):open():next(function(new_date)
      if not new_date then
        return
      end
      self:_replace_date(new_date)
    end)
  end

  local date_start = self:_get_date_under_cursor(-1)

  return Calendar.new({ date = Date.today() }):open():next(function(new_date)
    if not new_date then
      return nil
    end
    local date_string = new_date:to_wrapped_string(not inactive)
    if date_start then
      date_string = '--' .. date_string
      vim.cmd('norm!x')
    end
    vim.cmd(string.format('norm!a%s', date_string))
  end)
end

function OrgMappings:org_toggle_timestamp_type()
  local date = self:_get_date_under_cursor()
  if not date then
    return
  end

  date.active = not date.active
  self:_replace_date(date)
end

---@param direction string
---@param use_fast_access? boolean
---@return boolean
function OrgMappings:_change_todo_state(direction, use_fast_access)
  local headline = self.files:get_closest_headline()
  local current_keyword = headline:get_todo()
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
      next_state = todo_state:get_reset_todo(headline)
    end
  end

  if not next_state then
    return false
  end

  if next_state.value == current_keyword then
    if current_keyword ~= '' then
      utils.echo_info('TODO state was already ', { {
        next_state.value,
        next_state.hl,
      } })
    end
    return false
  end

  headline:set_todo(next_state.value)
  return true
end

---@param date OrgDate
function OrgMappings:_replace_date(date)
  local line = vim.fn.getline(date.range.start_line)
  local view = vim.fn.winsaveview() or {}
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

---@return OrgDate|nil
function OrgMappings:_get_date_under_cursor(col_offset)
  col_offset = col_offset or 0
  local col = vim.fn.col('.') + col_offset
  local line = vim.fn.line('.') or 0
  local item = self.files:get_closest_headline_or_nil()
  local dates = {}
  if item then
    dates = vim.tbl_filter(function(date)
      return date.range:is_in_range(line, col)
    end, item:get_all_dates())
  else
    dates = Date.parse_all_from_line(vim.fn.getline('.'), line)
  end

  if #dates == 0 then
    return nil
  end

  -- TODO: this will result in a bug, when more than one date is in the line
  return dates[1]
end

---@param amount number
---@param span string
---@param fallback string
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

---@param headline OrgHeadline
function OrgMappings:_goto_headline(headline)
  local current_file_path = utils.current_file_path()
  if headline.file.filename ~= current_file_path then
    vim.cmd(string.format('edit %s', headline.file.filename))
  else
    vim.cmd([[normal! m']]) -- add link source to jumplist
  end
  vim.fn.cursor({ headline:get_range().start_line, 1 })
  vim.cmd([[normal! zv]])
end

return OrgMappings

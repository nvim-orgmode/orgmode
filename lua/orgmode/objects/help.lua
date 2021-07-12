local utils = require('orgmode.utils')
local config = require('orgmode.config')

local helps = {
  org = {
    { key = 'org_refile', description = 'Refile subtree under cursor to destination' },
    { key = 'org_increase_date', description = 'Increase date under cursor by 1 day' },
    { key = 'org_decrease_date', description = 'Decrease date under cursor by 1 day' },
    { key = 'org_change_date', description = 'Change date under cursor via calendar popup' },
    { key = 'org_todo', description = 'Forward change TODO state of current headline' },
    { key = 'org_todo_prev', description = 'Backward change TODO state of current headline' },
    { key = 'org_toggle_checkbox', description = 'Toggle checkbox state' },
    { key = 'org_open_at_point', description = 'Open hyperlink or date under cursor' },
    { key = 'org_cycle', description = 'Toggle folding on current headline' },
    { key = 'org_global_cycle', description = 'Toggle folding in whole file' },
    { key = 'org_archive_subtree', description = 'Archive subtree to archive file' },
    { key = 'org_set_tags_command', description = 'Change tags of current headline' },
    { key = 'org_toggle_archive_tag', description = 'toggle "ARCHIVE" tag on current headline' },
    { key = 'org_do_promote', description = 'Promote headline' },
    { key = 'org_do_demote', description = 'Demote headline' },
    { key = 'org_promote_subtree', description = 'Promote whole subtree' },
    { key = 'org_demote_subtree', description = 'Demote whole subtree' },
    { key = 'org_meta_return', description = 'Add headline, list item or checkbox (context aware)' },
    { key = 'org_insert_heading_respect_content', description = 'Add new headline after current subtree' },
    { key = 'org_insert_todo_heading', description = 'Add new TODO headline on line right after current line' },
    { key = 'org_insert_todo_heading_respect_content', description = 'Add new TODO headline after current subtree' },
    { key = 'org_move_subtree_up', description = 'Move subtree up' },
    { key = 'org_move_subtree_down', description = 'Move subtree down' },
    { key = 'org_export', description = 'Open export options' },
    { key = 'org_show_help', description = 'Show this help' },
  },
  orgagenda = {
    { key = 'org_agenda_later', description = 'Go forward one span' },
    { key = 'org_agenda_earlier', description = 'Go bakckward one span' },
    { key = 'org_agenda_goto_today', description = "Go to today's span" },
    { key = 'org_agenda_goto_date', description = 'Jump to specific date' },
    { key = 'org_agenda_day_view', description = 'Show day view' },
    { key = 'org_agenda_week_view', description = 'Show week view' },
    { key = 'org_agenda_month_view', description = 'Show month view' },
    { key = 'org_agenda_year_view', description = 'Show year view' },
    { key = 'org_agenda_switch_to', description = 'Open in current window' },
    { key = 'org_agenda_goto', description = 'Open in another window' },
    { key = 'org_agenda_redo', description = 'Reload org files and redraw' },
    { key = 'org_agenda_quit', description = 'Close agenda' },
    { key = 'org_agenda_show_help', description = 'Show this help' },
  },
  capture = {
    { key = 'org_capture_finalize', description = 'Save to default notes file and close the window' },
    { key = 'org_capture_refile', description = 'Save to specific destination' },
    { key = 'org_capture_kill', description = 'Close without saving' },
  },
}

local Help = {
  buf = nil,
  win = nil
}

---@return string[]
function Help.prepare_content()
  local mappings = config.mappings
  local ft = vim.bo.filetype
  if ft == 'orgagenda' then
    local content = {' **Orgmode mappings - Agenda:**', ''}
    for _, item in ipairs(helps.orgagenda) do
      local maps = mappings.agenda[item.key]
      if type(maps) == 'table' then
        maps = table.concat(maps, ', ')
      end
      table.insert(content, string.format('  `%-6s` - %s', maps, item.description))
    end
    table.insert(content, '')
    table.insert(content, string.format('  `%-6s` - %s', '<Esc>, q', 'Close this help'))
    return content
  end

  local has_capture, is_capture = pcall(vim.api.nvim_buf_get_var, 0, 'org_capture')
  local content = {}
  if has_capture and is_capture then
  content = {' **Orgmode mappings Capture + Org:**', '', '  __Capture__'}
    for _, item in ipairs(helps.capture) do
      local maps = mappings.capture[item.key]
      if type(maps) == 'table' then
        maps = table.concat(maps, ', ')
      end
      table.insert(content, string.format('  `%-12s` - %s', maps, item.description))
    end
    table.insert(content, '  __Org__')
  else
    content = {' **Orgmode mappings - Org:**', ''}
  end

  for _, item in ipairs(helps.org) do
      local maps = mappings.org[item.key]
      if type(maps) == 'table' then
        maps = table.concat(maps, ', ')
      end
    table.insert(content, string.format('  `%-12s` - %s', maps, item.description))
  end

  table.insert(content, '')
  table.insert(content, string.format('  `%-12s` - %s', '<Esc>, q', 'Close this help'))
  return content
end

function Help.show()
  local opts = {
    relative = 'editor',
    width = vim.o.columns / 2,
    height = vim.o.lines - 10,
    anchor = 'NW',
    style = 'minimal',
    border = 'single',
    row = 5,
    col = vim.o.columns / 4,
  }

  local content = Help.prepare_content()
  local longest = utils.reduce(content, function(acc, item)
    return math.max(acc, item:len())
  end, 0)

  opts.width = math.min(longest + 2, vim.o.columns - 2)
  opts.height = math.min(#content + 1, vim.o.lines - 2)
  opts.row = (vim.o.lines - opts.height) / 2
  opts.col = (vim.o.columns - opts.width) / 2

  Help.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(Help.buf, 'orghelp')
  vim.api.nvim_buf_set_option(Help.buf, 'filetype', 'orghelp')
  vim.api.nvim_buf_set_option(Help.buf, 'bufhidden', 'wipe')
  Help.win = vim.api.nvim_open_win(Help.buf, true, opts)

  vim.api.nvim_buf_set_lines(Help.buf, 0, -1, true, content)

  vim.api.nvim_win_set_option(Help.win, 'winhl', 'Normal:Normal')
  vim.api.nvim_win_set_option(Help.win, 'wrap', false)
  vim.api.nvim_win_set_option(Help.win, 'conceallevel', 3)
  vim.api.nvim_win_set_option(Help.win, 'concealcursor', 'nvic')
  vim.api.nvim_buf_set_option(Help.buf, 'modifiable', false)
  vim.api.nvim_buf_set_var(Help.buf, 'indent_blankline_enabled', false)

  utils.buf_keymap(Help.buf, 'n', 'q', ':bw!<CR>')
  utils.buf_keymap(Help.buf, 'n', '<Esc>', ':bw!<CR>')

  vim.cmd[[autocmd BufWipeout <buffer> lua require('orgmode.objects.help').dispose()]]
end

function Help.dispose()
  Help.win = nil
  Help.buf = nil
end

return Help

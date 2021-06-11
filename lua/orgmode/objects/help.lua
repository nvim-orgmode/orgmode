local utils = require('orgmode.utils')
local config = require('orgmode.config')

-- TODO: Sort
local helps = {
  org = {
    org_capture_refile = 'Refile subtree under cursor to destination',
    org_increase_date = 'Increase date under cursor by 1 day',
    org_decrease_date = 'Decrease date under cursor by 1 day',
    org_change_date = 'Change date under cursor via calendar popup',
    org_todo = 'Forward change TODO state of current headline',
    org_todo_prev = 'Backward change TODO state of current headline',
    org_toggle_checkbox = 'Toggle checkbox state',
    org_cycle = 'Toggle folding on current headline',
    org_global_cycle = 'Toggle folding in whole file',
    org_archive_subtree = 'Archive subtree to archive file',
    org_set_tags_command = 'Change tasg of current headline',
    org_toggle_archive_tag = 'toggle "ARCHIVE" tag on current headline',
    org_do_promote = 'Promote headline',
    org_do_demote = 'Demote headline',
    org_meta_return = 'Add headline, list item or checkbox (context aware)',
    org_insert_heading_respect_content = 'Add new headline after current subtree',
    org_insert_todo_heading = 'Add new TODO headline on line right after current line',
    org_insert_todo_heading_respect_content = 'Add new TODO headline after current subtree',
    org_move_subtree_up = 'Move subtree up',
    org_move_subtree_down = 'Move subtree down',
    org_show_help = 'Show this help',
  },
  orgagenda = {
    org_agenda_later = 'Go forward one span',
    org_agenda_earlier = 'Go bakckward one span',
    org_agenda_goto_today = "Go to today's span",
    org_agenda_day_view = 'Show day view',
    org_agenda_week_view = 'Show week view',
    org_agenda_month_view = 'Show month view',
    org_agenda_year_view = 'Show year view',
    org_agenda_quit = 'Close agenda',
    org_agenda_switch_to = 'Open in current window',
    org_agenda_goto = 'Open in another window',
    org_agenda_goto_date = 'Jump to specific date',
    org_agenda_redo = 'reload org files and redraw',
    org_show_help = 'Show this help',
  },
  capture = {
    org_capture_finalize = 'Save to default notes file and close the window',
    org_capture_refile = 'Save to specific destination',
    org_capture_kill = 'Close without saving',
    org_show_help = 'Show this help',
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
  local content = {' Orgmode mappings:', ''}
  if ft == 'orgagenda' then
    for k, _ in pairs(mappings.agenda) do
      local maps = mappings.agenda[k]
      if type(maps) == 'table' then
        maps = table.concat(maps, ', ')
      end
      table.insert(content, string.format('  `%-6s` - %s', maps, helps.orgagenda[k] or 'No description, submit an issue to repository.'))
    end
    table.insert(content, '')
    table.insert(content, string.format('  `%-6s` - %s', '<Esc>, q', 'Close this help'))
    return content
  end

  local has_capture, is_capture = pcall(vim.api.nvim_buf_get_var, 0, 'org_capture')
  if has_capture and is_capture then
    for k, _ in pairs(mappings.capture) do
      local maps = mappings.capture[k]
      if type(maps) == 'table' then
        maps = table.concat(maps, ', ')
      end
      table.insert(content, string.format('  `%-12s` - %s', maps, helps.capture[k] or 'No description, submit an issue to repository.'))
    end
    table.insert(content, '')
  end

  for k, _ in pairs(mappings.org) do
      local maps = mappings.org[k]
      if type(maps) == 'table' then
        maps = table.concat(maps, ', ')
      end
    table.insert(content, string.format('  `%-12s` - %s', maps, helps.org[k] or 'No description, submit an issue to repository.'))
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
  Help.win = vim.api.nvim_open_win(Help.buf, true, opts)

  vim.api.nvim_buf_set_lines(Help.buf, 0, -1, true, content)

  vim.api.nvim_win_set_option(Help.win, 'winhl', 'Normal:Normal')
  vim.api.nvim_win_set_option(Help.win, 'wrap', false)
  vim.api.nvim_win_set_option(Help.win, 'conceallevel', 3)
  vim.api.nvim_win_set_option(Help.win, 'concealcursor', 'nvic')
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

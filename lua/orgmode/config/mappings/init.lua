local m = require('orgmode.config.mappings.map_entry')

return {
  global = {
    org_agenda = m.action('agenda.prompt', { opts = { buffer = false, desc = 'org agenda' } }),
    org_capture = m.action('capture.prompt', { opts = { buffer = false, desc = 'org capture' } }),
  },
  agenda = {
    org_agenda_later = m.action(
      'agenda.advance_span',
      { args = { 1 }, opts = { desc = 'org next agenda span', help_desc = 'Go forward one span' } }
    ),
    org_agenda_earlier = m.action(
      'agenda.advance_span',
      { args = { -1 }, opts = { desc = 'org prev agenda span', help_desc = 'Go backward one span' } }
    ),
    org_agenda_goto_today = m.action(
      'agenda.reset',
      { opts = { desc = 'org goto today', help_desc = "Go to today's span" } }
    ),
    org_agenda_day_view = m.action(
      'agenda.change_span',
      { args = { 'day' }, opts = { desc = 'org day view', help_desc = 'Show day view' } }
    ),
    org_agenda_week_view = m.action(
      'agenda.change_span',
      { args = { 'week' }, opts = { desc = 'org week view', help_desc = 'Show week view' } }
    ),
    org_agenda_month_view = m.action(
      'agenda.change_span',
      { args = { 'month' }, opts = { desc = 'org month view', help_desc = 'Show month view' } }
    ),
    org_agenda_year_view = m.action(
      'agenda.change_span',
      { args = { 'year' }, opts = { desc = 'org year view', help_desc = 'Show year view' } }
    ),
    org_agenda_quit = m.action('agenda.quit', { opts = { desc = 'org close agenda', help_desc = 'Close agenda' } }),
    org_agenda_switch_to = m.action(
      'agenda.switch_to_item',
      { opts = { desc = 'org open agenda item (same buffer)', help_desc = 'Open in current window' } }
    ),
    org_agenda_goto = m.action(
      'agenda.goto_item',
      { opts = { desc = 'org open agenda item (split buffer)', help_desc = 'Open in another window' } }
    ),
    org_agenda_goto_date = m.action(
      'agenda.goto_date',
      { opts = { desc = 'org goto date', help_desc = 'Jump to specific date' } }
    ),
    org_agenda_redo = m.action(
      'agenda.redo',
      { opts = { desc = 'org redo', help_desc = 'Reload org files and redraw' } }
    ),
    org_agenda_todo = m.action(
      'agenda.change_todo_state',
      { opts = { desc = 'org cycle todo state', help_desc = 'Change TODO state of an item' } }
    ),
    org_agenda_clock_in = m.action(
      'agenda.clock_in',
      { opts = { desc = 'org clock in', help_desc = 'Clock in item under cursor' } }
    ),
    org_agenda_clock_out = m.action(
      'agenda.clock_out',
      { opts = { desc = 'org clock out', help_desc = 'Clock out currently active clocked item' } }
    ),
    org_agenda_clock_cancel = m.action(
      'agenda.clock_cancel',
      { opts = { desc = 'org clock cancel', help_desc = 'Cancel clocking on currently active clocked item' } }
    ),
    org_agenda_set_effort = m.action(
      'agenda.set_effort',
      { opts = { desc = 'org set effort', help_desc = 'Set effort estimate for item under cursor' } }
    ),
    org_agenda_clock_goto = m.action(
      'clock.org_clock_goto',
      { opts = { desc = 'org goto active clock item', help_desc = 'Jump to currently active clock item' } }
    ),
    org_agenda_clockreport_mode = m.action(
      'agenda.toggle_clock_report',
      { opts = { desc = 'org clockreport mode', help_desc = 'Toggle clock report for current agenda time range' } }
    ),
    org_agenda_priority = m.action(
      'agenda.set_priority',
      { opts = { desc = 'org set priority', help_desc = 'Set priority for current item' } }
    ),
    org_agenda_priority_up = m.action(
      'agenda.priority_up',
      { opts = { desc = 'org increase priority', help_desc = 'Increase priority for current item' } }
    ),
    org_agenda_priority_down = m.action(
      'agenda.priority_down',
      { opts = { desc = 'org decrease priority', help_desc = 'Decrease priority for current item' } }
    ),
    org_agenda_archive = m.action(
      'agenda.archive',
      { opts = { desc = 'org archive subtree', help_desc = 'Archive headline to archive file' } }
    ),
    org_agenda_toggle_archive_tag = m.action(
      'agenda.toggle_archive_tag',
      { opts = { desc = 'org toggle archive tag', help_desc = 'Toggle "ARCHIVE" tag on current headline' } }
    ),
    org_agenda_set_tags = m.action(
      'agenda.set_tags',
      { opts = { desc = 'org set tags', help_desc = 'Change tags of current headline' } }
    ),
    org_agenda_deadline = m.action(
      'agenda.set_deadline',
      { opts = { desc = 'org deadline', help_desc = 'Insert/Update deadline date on current headline' } }
    ),
    org_agenda_schedule = m.action(
      'agenda.set_schedule',
      { opts = { desc = 'org schedule', help_desc = 'Insert/Update scheduled date on current headline' } }
    ),
    org_agenda_filter = m.action('agenda.filter', {
      opts = {
        desc = 'org filter',
        help_desc = 'Open prompt that allows filtering by category, tags and title(vim regex)',
      },
    }),
    org_agenda_refile = m.action('agenda.refile', {
      opts = {
        desc = 'org refile',
        help_desc = 'Refile headline to specific destination',
      },
    }),
    org_agenda_show_help = m.action(
      'org_mappings.show_help',
      { args = { 'agenda' }, opts = { desc = 'org show help', help_desc = 'Show this help' } }
    ),
  },
  capture = {
    org_capture_finalize = m.action(
      'capture.refile',
      { opts = { desc = 'org finalize', help_desc = 'Save to default notes file and close the window' } }
    ),
    org_capture_refile = m.action(
      'capture.refile_to_destination',
      { opts = { desc = 'org refile', help_desc = 'Save to specific destination' } }
    ),
    org_capture_kill = m.action('capture.kill', { opts = { desc = 'org kill', help_desc = 'Close without saving' } }),
    org_capture_show_help = m.action(
      'org_mappings.show_help',
      { args = { 'capture' }, opts = { desc = 'org show help', help_desc = 'Show this help' } }
    ),
  },
  note = {
    org_note_finalize = m.action(
      'capture.closing_note.finish',
      { opts = { desc = 'org finalize note', help_desc = 'Save note and close the window' } }
    ),
    org_note_kill = m.action(
      'capture.closing_note.kill',
      { opts = { desc = 'org kill note', help_desc = 'Close without saving' } }
    ),
    org_note_show_help = m.action('org_mappings.show_help', {
      args = { 'note' },
      opts = { desc = 'org show help' },
    }),
  },
  org = {
    org_refile = m.action(
      'capture.refile_headline_to_destination',
      { opts = { desc = 'org refile', help_desc = 'Refile headline to specific destination' } }
    ),
    org_timestamp_up_day = m.action(
      'org_mappings.timestamp_up_day',
      { opts = { desc = 'org increase timestamp (day)', help_desc = 'Increase timestamp by one day' } }
    ),
    org_timestamp_down_day = m.action(
      'org_mappings.timestamp_down_day',
      { opts = { desc = 'org decrease timestamp (day)', help_desc = 'Decrease timestamp by one day' } }
    ),
    org_timestamp_up = m.action('org_mappings.timestamp_up', {
      opts = {
        desc = 'org increase timestamp',
        help_desc = 'Increase date part under cursor (year/month/day/hour/minute/repeater/active|inactive)',
      },
    }),
    org_timestamp_down = m.action('org_mappings.timestamp_down', {
      opts = {
        desc = 'org decrease timestamp',
        help_desc = 'Decrease date part under cursor (year/month/day/hour/minute/repeater/active|inactive)',
      },
    }),
    org_change_date = m.action(
      'org_mappings.change_date',
      { opts = { desc = 'org change date', help_desc = 'Change date under cursor via calendar popup' } }
    ),
    org_todo = m.action(
      'org_mappings.todo_next_state',
      { opts = { desc = 'org next todo state', help_desc = 'Forward change TODO state of current headline' } }
    ),
    org_todo_prev = m.action(
      'org_mappings.todo_prev_state',
      { opts = { desc = 'org prev todo state', help_desc = 'Backward change TODO state of current headline' } }
    ),
    org_priority = m.action(
      'org_mappings.set_priority',
      { opts = { desc = 'org cycle priority', help_desc = 'Change the priority of the current headline' } }
    ),
    org_priority_up = m.action(
      'org_mappings.priority_up',
      { opts = { desc = 'org increase priority', help_desc = 'Increase priority of headline' } }
    ),
    org_priority_down = m.action(
      'org_mappings.priority_down',
      { opts = { desc = 'org decrease priority', help_desc = 'Decrease priority of headline' } }
    ),
    org_toggle_checkbox = m.action(
      'org_mappings.toggle_checkbox',
      { opts = { desc = 'org toggle checkbox', help_desc = 'Toggle checkbox' } }
    ),
    org_toggle_heading = m.action(
      'org_mappings.toggle_heading',
      { opts = { desc = 'org toggle headline', help_desc = 'Toggle current line to headline and vice versa' } }
    ),
    org_open_at_point = m.action(
      'org_mappings.open_at_point',
      { opts = { desc = 'org open', help_desc = 'Open hyperlink or date under cursor' } }
    ),
    org_edit_special = m.action(
      'org_mappings.edit_special',
      { opts = { desc = 'org edit special', help_desc = 'Edit the source block under the cursor in another buffer' } }
    ),
    org_cycle = m.action('org_mappings.cycle', { opts = { desc = 'org toggle fold', help_desc = 'Toggle folding' } }),
    org_global_cycle = m.action(
      'org_mappings.global_cycle',
      { opts = { desc = 'org toggle fold (whole file)', help_desc = 'Toggle folding (whole file)' } }
    ),
    org_archive_subtree = m.action(
      'org_mappings.archive',
      { opts = { desc = 'org archive subtree', help_desc = 'Archive subtree to archive file' } }
    ),
    org_set_tags_command = m.action(
      'org_mappings.set_tags',
      { opts = { desc = 'org set tags', help_desc = 'Change tags of current headline' } }
    ),
    org_toggle_archive_tag = m.action(
      'org_mappings.toggle_archive_tag',
      { opts = { desc = 'org toggle archive tag', help_desc = 'Toggle "ARCHIVE" tag on current headline' } }
    ),
    org_do_promote = m.action(
      'org_mappings.do_promote',
      { opts = { desc = 'org promote headline', help_desc = 'Promote headline' } }
    ),
    org_do_demote = m.action(
      'org_mappings.do_demote',
      { opts = { desc = 'org demote headline', help_desc = 'Demote headline' } }
    ),
    org_promote_subtree = m.action(
      'org_mappings.do_promote',
      { args = { true }, opts = { desc = 'org promote subtree', help_desc = 'Promote whole subtree' } }
    ),
    org_demote_subtree = m.action(
      'org_mappings.do_demote',
      { args = { true }, opts = { desc = 'org demote subtree', help_desc = 'Demote whole subtree' } }
    ),
    org_meta_return = m.action(
      'org_mappings.meta_return',
      { opts = { desc = 'org meta return', help_desc = 'Add headline, list item or checkbox (context aware)' } }
    ),
    org_insert_heading_respect_content = m.action('org_mappings.insert_heading_respect_content', {
      opts = { desc = 'org insert headline (respect content)', help_desc = 'Add new headline after current subtree' },
    }),
    org_insert_todo_heading = m.action(
      'org_mappings.insert_todo_heading',
      { opts = { desc = 'org insert todo', help_desc = 'Add new TODO headline on line right after current line' } }
    ),
    org_insert_todo_heading_respect_content = m.action('org_mappings.insert_todo_heading_respect_content', {
      opts = { desc = 'org insert todo (respect content)', help_desc = 'Add new TODO headline after current subtree' },
    }),
    org_move_subtree_up = m.action(
      'org_mappings.move_subtree_up',
      { opts = { desc = 'org move subtree up', help_desc = 'Move subtree up' } }
    ),
    org_move_subtree_down = m.action(
      'org_mappings.move_subtree_down',
      { opts = { desc = 'org move subtree down', help_desc = 'Move subtree down' } }
    ),
    org_export = m.action('org_mappings.export', { opts = { desc = 'org export', help_desc = 'Open export options' } }),
    org_return = m.action('org_mappings.org_return', { modes = { 'i' }, opts = { desc = 'org return' } }),
    org_next_visible_heading = m.action('org_mappings.next_visible_heading', {
      modes = { 'n', 'x' },
      opts = { desc = 'org next visible headline', help_desc = 'Go to next headline (any level)' },
    }),
    org_previous_visible_heading = m.action('org_mappings.previous_visible_heading', {
      modes = { 'n', 'x' },
      opts = { desc = 'org prev visible headline', help_desc = 'Go to previous headline (any level)' },
    }),
    org_forward_heading_same_level = m.action(
      'org_mappings.forward_heading_same_level',
      { opts = { desc = 'org next headline (same level)', help_desc = 'Go to next headline at the same level' } }
    ),
    org_backward_heading_same_level = m.action(
      'org_mappings.backward_heading_same_level',
      { opts = { desc = 'org prev headline (same level)', help_desc = 'Go to previous headline at the same level' } }
    ),
    outline_up_heading = m.action(
      'org_mappings.outline_up_heading',
      { opts = { desc = 'org goto parent headline', help_desc = 'Go to parent headline' } }
    ),
    org_deadline = m.action(
      'org_mappings.org_deadline',
      { opts = { desc = 'org deadline', help_desc = 'Insert/Update deadline date' } }
    ),
    org_schedule = m.action(
      'org_mappings.org_schedule',
      { opts = { desc = 'org schedule', help_desc = 'Insert/Update scheduled date' } }
    ),
    org_time_stamp = m.action(
      'org_mappings.org_time_stamp',
      { opts = { desc = 'org timestamp', help_desc = 'Insert date under cursor' } }
    ),
    org_time_stamp_inactive = m.action('org_mappings.org_time_stamp', {
      args = { true },
      opts = { desc = 'org timestamp (inactive)', help_desc = 'Insert/Update inactive date under cursor' },
    }),
    org_insert_link = m.action(
      'org_mappings.insert_link',
      { opts = { desc = 'org insert link', help_desc = 'Insert a hyperlink' } }
    ),
    org_store_link = m.action(
      'org_mappings.store_link',
      { opts = { desc = 'org store link', help_desc = 'Store link to current headline' } }
    ),
    org_clock_in = m.action(
      'clock.org_clock_in',
      { opts = { desc = 'org clock in', help_desc = 'Clock in current headline' } }
    ),
    org_clock_out = m.action(
      'clock.org_clock_out',
      { opts = { desc = 'org clock out', help_desc = 'Clock out current headline' } }
    ),
    org_clock_cancel = m.action(
      'clock.org_clock_cancel',
      { opts = { desc = 'org clock cancel', help_desc = 'Cancel active clock on current headline' } }
    ),
    org_clock_goto = m.action(
      'clock.org_clock_goto',
      { opts = { desc = 'org clock goto', help_desc = 'Jump to currently clocked in headline' } }
    ),
    org_set_effort = m.action(
      'clock.org_set_effort',
      { opts = { desc = 'org set effort', help_desc = 'Set effort estimate on current headline' } }
    ),
    org_show_help = m.action('org_mappings.show_help', {
      args = { 'org' },
      opts = { desc = 'org show help', help_desc = 'Show this help' },
    }),
    org_babel_tangle = m.action(
      'org_mappings.org_babel_tangle',
      { opts = { desc = 'org tangle', help_desc = 'Tangle current file' } }
    ),
  },
  edit_src = {
    org_edit_src_abort = m.custom(
      [[<Cmd>lua require('orgmode.objects.edit_special').abort()<CR>]],
      { opts = { desc = 'org abort', help_desc = 'Abort edit special buffer changes and discard content' } }
    ),
    org_edit_src_show_help = m.custom(
      [[<Cmd>lua require('orgmode.objects.help').show('edit_src')<CR>]],
      { opts = { desc = 'org show help', help_desc = 'Show this help' } }
    ),
    org_edit_src_save = m.custom(
      [[<Cmd>lua require('orgmode.objects.edit_special'):new():write()<CR>]],
      { opts = { desc = 'org save', help_desc = 'Apply changes from the special buffer to the source Org buffer' } }
    ),
  },
  text_objects = {
    inner_heading = m.text_object('inner_heading', { help_desc = 'Select inner headline' }),
    around_heading = m.text_object('around_heading', { help_desc = 'Select around headline' }),
    inner_subtree = m.text_object('inner_subtree', { help_desc = 'Select inner subtree' }),
    around_subtree = m.text_object('around_subtree', { help_desc = 'Select around subtree' }),
    inner_heading_from_root = m.text_object(
      'inner_heading_from_root',
      { help_desc = 'Select inner headline from root headline' }
    ),
    around_heading_from_root = m.text_object(
      'around_heading_from_root',
      { help_desc = 'Select around headline from root headline' }
    ),
    inner_subtree_from_root = m.text_object(
      'inner_subtree_from_root',
      { help_desc = 'Select inner subtree from root headline' }
    ),
    around_subtree_from_root = m.text_object(
      'around_subtree_from_root',
      { help_desc = 'Select around subtree from root headline' }
    ),
  },
}

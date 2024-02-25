local m = require('orgmode.config.mappings.map_entry')

return {
  global = {
    org_agenda = m.action('agenda.prompt', { opts = { buffer = false, desc = 'org agenda' } }),
    org_capture = m.action('capture.prompt', { opts = { buffer = false, desc = 'org capture' } }),
  },
  agenda = {
    org_agenda_later = m.action('agenda.advance_span', { args = { 1 }, opts = { desc = 'org next agenda span' } }),
    org_agenda_earlier = m.action('agenda.advance_span', { args = { -1 }, opts = { desc = 'org prev agenda span' } }),
    org_agenda_goto_today = m.action('agenda.reset', { opts = { desc = 'org goto today' } }),
    org_agenda_day_view = m.action('agenda.change_span', { args = { 'day' }, opts = { desc = 'org day view' } }),
    org_agenda_week_view = m.action('agenda.change_span', { args = { 'week' }, opts = { desc = 'org week view' } }),
    org_agenda_month_view = m.action('agenda.change_span', { args = { 'month' }, opts = { desc = 'org month view' } }),
    org_agenda_year_view = m.action('agenda.change_span', { args = { 'year' }, opts = { desc = 'org year view' } }),
    org_agenda_quit = m.action('agenda.quit', { opts = { desc = 'org close agenda' } }),
    org_agenda_switch_to = m.action(
      'agenda.switch_to_item',
      { opts = { desc = 'org open agenda item (same buffer)' } }
    ),
    org_agenda_goto = m.action('agenda.goto_item', { opts = { desc = 'org open agenda item (split buffer)' } }),
    org_agenda_goto_date = m.action('agenda.goto_date', { opts = { desc = 'org goto date' } }),
    org_agenda_redo = m.action('agenda.redo', { opts = { desc = 'org redo' } }),
    org_agenda_todo = m.action('agenda.change_todo_state', { opts = { desc = 'org cycle todo state' } }),
    org_agenda_clock_in = m.action('agenda.clock_in', { opts = { desc = 'org clock in' } }),
    org_agenda_clock_out = m.action('agenda.clock_out', { opts = { desc = 'org clock out' } }),
    org_agenda_clock_cancel = m.action('agenda.clock_cancel', { opts = { desc = 'org clock cancel' } }),
    org_agenda_set_effort = m.action('agenda.set_effort', { opts = { desc = 'org set effort' } }),
    org_agenda_clock_goto = m.action('clock.org_clock_goto', { opts = { desc = 'org goto active clock item' } }),
    org_agenda_clockreport_mode = m.action('agenda.toggle_clock_report', { opts = { desc = 'org clockreport mode' } }),
    org_agenda_priority = m.action('agenda.set_priority', { opts = { desc = 'org set priority' } }),
    org_agenda_priority_up = m.action('agenda.priority_up', { opts = { desc = 'org increase priority' } }),
    org_agenda_priority_down = m.action('agenda.priority_down', { opts = { desc = 'org decrease priority' } }),
    org_agenda_archive = m.action('agenda.archive', { opts = { desc = 'org archive subtree' } }),
    org_agenda_toggle_archive_tag = m.action(
      'agenda.toggle_archive_tag',
      { opts = { desc = 'org toggle archive tag' } }
    ),
    org_agenda_set_tags = m.action('agenda.set_tags', { opts = { desc = 'org set tags' } }),
    org_agenda_deadline = m.action('agenda.set_deadline', { opts = { desc = 'org deadline' } }),
    org_agenda_schedule = m.action('agenda.set_schedule', { opts = { desc = 'org schedule' } }),
    org_agenda_filter = m.action('agenda.filter', { opts = { desc = 'org filter' } }),
    org_agenda_show_help = m.action('org_mappings.show_help', { opts = { desc = 'org show help' } }),
  },
  capture = {
    org_capture_finalize = m.action('capture.refile', { opts = { desc = 'org finalize' } }),
    org_capture_refile = m.action('capture.refile_to_destination', { opts = { desc = 'org refile' } }),
    org_capture_kill = m.action('capture.kill', { opts = { desc = 'org kill' } }),
    org_capture_show_help = m.action('org_mappings.show_help', { opts = { desc = 'org show help' } }),
  },
  note = {
    org_note_finalize = m.action('capture.closing_note.finish', { opts = { desc = 'org finalize note' } }),
    org_note_kill = m.action('capture.closing_note.kill', { opts = { desc = 'org kill note' } }),
    org_note_show_help = m.action('org_mappings.show_help', { opts = { desc = 'org show help' } }),
  },
  org = {
    org_refile = m.action('capture.refile_headline_to_destination', { opts = { desc = 'org refile' } }),
    org_timestamp_up_day = m.action(
      'org_mappings.timestamp_up_day',
      { opts = { desc = 'org increase timestamp (day)' } }
    ),
    org_timestamp_down_day = m.action(
      'org_mappings.timestamp_down_day',
      { opts = { desc = 'org decrease timestamp (day)' } }
    ),
    org_timestamp_up = m.action('org_mappings.timestamp_up', { opts = { desc = 'org increase timestamp' } }),
    org_timestamp_down = m.action('org_mappings.timestamp_down', { opts = { desc = 'org decrease timestamp' } }),
    org_change_date = m.action('org_mappings.change_date', { opts = { desc = 'org change date' } }),
    org_todo = m.action('org_mappings.todo_next_state', { opts = { desc = 'org next todo state' } }),
    org_todo_prev = m.action('org_mappings.todo_prev_state', { opts = { desc = 'org prev todo state' } }),
    org_priority = m.action('org_mappings.set_priority', { opts = { desc = 'org cycle priority' } }),
    org_priority_up = m.action('org_mappings.priority_up', { opts = { desc = 'org increase priority' } }),
    org_priority_down = m.action('org_mappings.priority_down', { opts = { desc = 'org decrease priority' } }),
    org_toggle_checkbox = m.action('org_mappings.toggle_checkbox', { opts = { desc = 'org toggle checkbox' } }),
    org_toggle_heading = m.action('org_mappings.toggle_heading', { opts = { desc = 'org toggle headline' } }),
    org_open_at_point = m.action('org_mappings.open_at_point', { opts = { desc = 'org open' } }),
    org_edit_special = m.action('org_mappings.edit_special', { opts = { desc = 'org edit special' } }),
    org_cycle = m.action('org_mappings.cycle', { opts = { desc = 'org toggle fold' } }),
    org_global_cycle = m.action('org_mappings.global_cycle', { opts = { desc = 'org toggle fold (whole file)' } }),
    org_archive_subtree = m.action('org_mappings.archive', { opts = { desc = 'org archive subtree' } }),
    org_set_tags_command = m.action('org_mappings.set_tags', { opts = { desc = 'org set tags' } }),
    org_toggle_archive_tag = m.action(
      'org_mappings.toggle_archive_tag',
      { opts = { desc = 'org toggle archive tag' } }
    ),
    org_do_promote = m.action('org_mappings.do_promote', { opts = { desc = 'org promote headline' } }),
    org_do_demote = m.action('org_mappings.do_demote', { opts = { desc = 'org demote headline' } }),
    org_promote_subtree = m.action(
      'org_mappings.do_promote',
      { args = { true }, opts = { desc = 'org promote subtree' } }
    ),
    org_demote_subtree = m.action(
      'org_mappings.do_demote',
      { args = { true }, opts = { desc = 'org demote subtree' } }
    ),
    org_meta_return = m.action('org_mappings.meta_return', { opts = { desc = 'org meta return' } }),
    org_insert_heading_respect_content = m.action(
      'org_mappings.insert_heading_respect_content',
      { opts = { desc = 'org insert headline (respect content)' } }
    ),
    org_insert_todo_heading = m.action('org_mappings.insert_todo_heading', { opts = { desc = 'org insert todo' } }),
    org_insert_todo_heading_respect_content = m.action(
      'org_mappings.insert_todo_heading_respect_content',
      { opts = { desc = 'org insert todo (respect content)' } }
    ),
    org_move_subtree_up = m.action('org_mappings.move_subtree_up', { opts = { desc = 'org move subtree up' } }),
    org_move_subtree_down = m.action('org_mappings.move_subtree_down', { opts = { desc = 'org move subtree down' } }),
    org_export = m.action('org_mappings.export', { opts = { desc = 'org export' } }),
    org_return = m.action('org_mappings.org_return', { modes = { 'i' }, opts = { desc = 'org return' } }),
    org_next_visible_heading = m.action('org_mappings.next_visible_heading', {
      modes = { 'n', 'x' },
      opts = { desc = 'org next visible headline' },
    }),
    org_previous_visible_heading = m.action(
      'org_mappings.previous_visible_heading',
      { modes = { 'n', 'x' }, opts = { desc = 'org prev visible headline' } }
    ),
    org_forward_heading_same_level = m.action(
      'org_mappings.forward_heading_same_level',
      { opts = { desc = 'org next headline (same level)' } }
    ),
    org_backward_heading_same_level = m.action(
      'org_mappings.backward_heading_same_level',
      { opts = { desc = 'org prev headline (same level)' } }
    ),
    outline_up_heading = m.action('org_mappings.outline_up_heading', { opts = { desc = 'org goto parent headline' } }),
    org_deadline = m.action('org_mappings.org_deadline', { opts = { desc = 'org deadline' } }),
    org_schedule = m.action('org_mappings.org_schedule', { opts = { desc = 'org schedule' } }),
    org_time_stamp = m.action('org_mappings.org_time_stamp', { opts = { desc = 'org timestamp' } }),
    org_time_stamp_inactive = m.action(
      'org_mappings.org_time_stamp',
      { args = { true }, opts = { desc = 'org timestamp (inactive)' } }
    ),
    org_insert_link = m.action('org_mappings.insert_link', { opts = { desc = 'org insert link' } }),
    org_store_link = m.action('org_mappings.store_link', { opts = { desc = 'org store link' } }),
    org_clock_in = m.action('clock.org_clock_in', { opts = { desc = 'org clock in' } }),
    org_clock_out = m.action('clock.org_clock_out', { opts = { desc = 'org clock out' } }),
    org_clock_cancel = m.action('clock.org_clock_cancel', { opts = { desc = 'org clock cancel' } }),
    org_clock_goto = m.action('clock.org_clock_goto', { opts = { desc = 'org clock goto' } }),
    org_set_effort = m.action('clock.org_set_effort', { opts = { desc = 'org set effort' } }),
    org_show_help = m.action('org_mappings.show_help', { opts = { desc = 'org show help' } }),
    org_babel_tangle = m.action('org_mappings.org_babel_tangle', { opts = { desc = 'org tangle' } }),
  },
  edit_src = {
    org_edit_src_abort = m.custom(
      [[<Cmd>lua require('orgmode.objects.edit_special').abort()<CR>]],
      { opts = { desc = 'org abort' } }
    ),
    org_edit_src_show_help = m.custom(
      [[<Cmd>lua require('orgmode.objects.help').show({ type = 'edit_src' })<CR>]],
      { opts = { desc = 'org show help' } }
    ),
    org_edit_src_save = m.custom(
      [[<Cmd>lua require('orgmode.objects.edit_special'):new():write()<CR>]],
      { opts = { desc = 'org save' } }
    ),
  },
  text_objects = {
    inner_heading = m.text_object('inner_heading'),
    around_heading = m.text_object('around_heading'),
    inner_subtree = m.text_object('inner_subtree'),
    around_subtree = m.text_object('around_subtree'),
    inner_heading_from_root = m.text_object('inner_heading_from_root'),
    around_heading_from_root = m.text_object('around_heading_from_root'),
    inner_subtree_from_root = m.text_object('inner_subtree_from_root'),
    around_subtree_from_root = m.text_object('around_subtree_from_root'),
  },
}

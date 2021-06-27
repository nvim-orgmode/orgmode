return {
  agenda = {
    org_agenda_later = {'agenda.advance_span', 1},
    org_agenda_earlier = {'agenda.advance_span', -1},
    org_agenda_goto_today = {'agenda.reset'},
    org_agenda_day_view = {'agenda.change_span', 'day'},
    org_agenda_week_view = {'agenda.change_span', 'week'},
    org_agenda_month_view = {'agenda.change_span', 'month'},
    org_agenda_year_view = {'agenda.change_span', 'year'},
    org_agenda_quit = {'agenda.quit'},
    org_agenda_switch_to = {'agenda.switch_to_item'},
    org_agenda_goto = {'agenda.goto_item'},
    org_agenda_goto_date = {'agenda.goto_date'},
    org_agenda_redo = {'agenda.redo'},
    org_agenda_show_help = {'org_mappings.show_help'},
  },
  capture = {
    org_capture_finalize = {'capture.refile'},
    org_capture_refile = {'capture.refile_to_destination'},
    org_capture_kill = {'capture.kill'},
    org_capture_show_help = {'org_mappings.show_help'},
  },
  org = {
    org_refile = {'capture.refile_headline_to_destination'},
    org_increase_date = {'org_mappings.increase_date'},
    org_decrease_date = {'org_mappings.decrease_date'},
    org_change_date = {'org_mappings.change_date'},
    org_todo = {'org_mappings.todo_next_state'},
    org_todo_prev = {'org_mappings.todo_prev_state'},
    org_toggle_checkbox = {'org_mappings.toggle_checkbox'},
    org_open_at_point = {'org_mappings.open_at_point'},
    org_cycle = {'org_mappings.cycle'},
    org_global_cycle = {'org_mappings.global_cycle'},
    org_archive_subtree = {'org_mappings.archive'},
    org_set_tags_command = {'org_mappings.set_tags'},
    org_toggle_archive_tag = {'org_mappings.toggle_archive_tag'},
    org_do_promote = {'org_mappings.do_promote'},
    org_do_demote = {'org_mappings.do_demote'},
    org_promote_subtree = {'org_mappings.do_promote', true},
    org_demote_subtree = {'org_mappings.do_demote', true},
    org_meta_return = {'org_mappings.handle_return'},
    org_insert_heading_respect_content = {'org_mappings.insert_heading_respect_content'},
    org_insert_todo_heading = {'org_mappings.insert_todo_heading'},
    org_insert_todo_heading_respect_content = {'org_mappings.insert_todo_heading_respect_content'},
    org_move_subtree_up = {'org_mappings.move_subtree_up'},
    org_move_subtree_down = {'org_mappings.move_subtree_down'},
    org_show_help = {'org_mappings.show_help'},
  }
}

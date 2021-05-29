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
  },
  capture = {
    org_capture_finalize = {'capture.refile'},
    org_capture_refile = {'capture.refile_to_destination'},
    org_capture_kill = {'capture.kill'}
  },
  org = {
    org_capture_refile = {'capture.refile_headline_to_destination'},
    org_increase_date = {'org_mappings.increase_date'},
    org_decrease_date = {'org_mappings.decrease_date'},
    org_change_date = {'org_mappings.change_date'},
    org_todo = {'org_mappings.change_todo_state'}
  }
}
-- org_agenda_follow_mode = 'F', -- TODO

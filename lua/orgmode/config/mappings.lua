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
    org_agenda_switch_to = {'agenda.select_item'},
  }
}
-- org_agenda_goto_date = 'j', -- TODO
-- org_agenda_goto = {'<TAB>', '<LeftMouse>'}, -- TODO
-- org_agenda_follow_mode = 'F', -- TODO

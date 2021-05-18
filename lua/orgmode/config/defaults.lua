return {
  week_start_day = 1,
  org_agenda_files = '',
  org_default_notes_file = '',
  org_todo_keywords = {'TODO', 'NEXT', 'DONE'},
  org_agenda_skip_scheduled_if_done = false, -- hide DONE items if this is true
  org_deadline_warning_days = 14,
  -- https://emacs.stackexchange.com/a/12518
  -- https://stackoverflow.com/a/32426234/1474465
  -- TODO: Respect agenda settings
  org_agenda_span = 'week', -- day/week/month/year/number of days
  org_agenda_start_on_weekday = 1,
  org_agenda_start_day = nil, -- start from today + this modifier
}

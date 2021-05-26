return {
  org_agenda_files = '',
  org_default_notes_file = '',
  org_todo_keywords = {'TODO', 'DONE'},
  org_agenda_skip_scheduled_if_done = false, -- hide DONE items if this is true
  org_deadline_warning_days = 14,
  -- https://emacs.stackexchange.com/a/12518
  -- https://stackoverflow.com/a/32426234/1474465
  -- TODO: Respect agenda settings
  org_agenda_span = 'week', -- day/week/month/year/number of days
  org_agenda_start_on_weekday = 1,
  org_agenda_start_day = nil, -- start from today + this modifier
  org_agenda_templates = {},
  org_refile_targets = {},
  mappings = {
    disable_all = false,
    global = {
      org_agenda = '<Leader>oa',
      org_capture = '<Leader>oc',
    },
    agenda = {
      org_agenda_later = 'f',
      org_agenda_earlier = 'b',
      org_agenda_goto_today = '.',
      org_agenda_day_view = 'vd',
      org_agenda_week_view = 'vw',
      org_agenda_month_view = 'vm',
      org_agenda_year_view = 'vy',
      org_agenda_quit = 'q',
      org_agenda_switch_to = '<CR>',
      -- org_agenda_goto_date = 'j', -- TODO
      -- org_agenda_goto = {'<TAB>', '<LeftMouse>'}, -- TODO
      -- org_agenda_follow_mode = 'F', -- TODO
    },
    capture = {
      org_capture_finalize = '<C-c>',
      org_capture_refile = '<Leader>or',
      org_capture_kill = '<Leader>k'
    },
    org = {
      org_capture_refile = '<Leader>or',
      org_increase_date = '<C-a>',
      org_decrease_date = '<C-x>',
      org_change_date = 'cid',
    }
  }
}

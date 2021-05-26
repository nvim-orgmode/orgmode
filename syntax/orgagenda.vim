lua require('orgmode.agenda.highlights').define_agenda_colors()
syn match OrgAgendaDay /^\w\+\s\d\+\s\w\+\s\d\d\d\d$/
syn match OrgAgendaTags /:[^\s]*:$/
hi OrgBold gui=bold
hi default link OrgAgendaDay Statement
hi default link OrgAgendaTags OrgBold

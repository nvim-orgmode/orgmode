" syn match OrgTodo /\<TODO\>/
" syn match OrgNext /\<NEXT\>/
" syn match OrgDone /\<DONE\>/

syn match OrgAgendaDay /^\w\+\s\d\+\s\w\+\s\d\d\d\d$/

" TODO - Add better defaults
hi default link OrgTodo Red
hi default link OrgNext Blue
hi default link OrgDone Green

hi default link OrgAgendaDay Statement
hi default link OrgAgendaToday Identifier

hi default link OrgAgendaDeadline Red
hi default link OrgAgendaSchedulePast Yellow
hi default link OrgAgendaScheduleFuture Green

hi OrgBold gui=bold

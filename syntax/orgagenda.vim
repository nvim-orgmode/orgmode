syn match @org.agenda.day /^\S\+\s\+\d\+\s\S\+\s\d\d\d\d$/
syn match @org.agenda.tag /:[^ ]*:$/

hi default link @org.agenda.day Statement
hi default link @org.agenda.today @org.bold
hi default link @org.agenda.weekend @org.bold
hi default link @org.agenda.header Comment
hi default link @org.agenda.separator Comment
hi default @org.agenda.tag gui=bold cterm=bold

lua require('orgmode.colors.highlights').define_agenda_colors()
syn match OrgAgendaDay /^\S\+\s\+\d\+\s\S\+\s\d\d\d\d$/
syn match OrgAgendaTags /:[^ ]*:$/
syn match org_hyperlink	"\[\{2}[^][]*\(\]\[[^][]*\)\?\]\{2}" contains=org_hyperlinkBracketsLeft,org_hyperlinkURL,org_hyperlinkBracketsRight
syn match org_hyperlinkBracketsLeft	contained "\[\{2}"     conceal
syn match org_hyperlinkURL				    contained "[^][]*\]\[" conceal
syn match org_hyperlinkBracketsRight	contained "\]\{2}"     conceal

hi OrgBold gui=bold cterm=bold
hi OrgUnderline gui=underline cterm=underline
hi default link OrgAgendaDay Statement
hi default link OrgAgendaTags OrgBold

hi default link org_hyperlink Underlined

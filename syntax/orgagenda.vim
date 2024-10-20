syn match @org.agenda.day /^\S\+\s\+\d\+\s\S\+\s\d\d\d\d$/
syn match @org.agenda.tag /:[^ ]*:$/
syn match org_hyperlink	"\[\{2}[^][]*\(\]\[[^][]*\)\?\]\{2}" contains=org_hyperlinkBracketsLeft,org_hyperlinkURL,org_hyperlinkBracketsRight
syn match org_hyperlinkBracketsLeft	contained "\[\{2}"     conceal
syn match org_hyperlinkURL				    contained "[^][]*\]\[" conceal
syn match org_hyperlinkBracketsRight	contained "\]\{2}"     conceal

hi default link @org.agenda.day Statement
hi default link @org.agenda.today @org.bold
hi default link @org.agenda.weekend @org.bold
hi default @org.agenda.tag gui=bold cterm=bold

hi default link org_hyperlink @org.hyperlink

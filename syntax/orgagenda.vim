syn match @org.agenda.day /^\S\+\s\+\d\+\s\S\+\s\d\d\d\d$/
syn match @org.agenda.tag /:[^ ]*:$/
syn match org_hyperlink	"\[\{2}[^][]*\(\]\[[^][]*\)\?\]\{2}" contains=org_hyperlinkBracketsLeft,org_hyperlinkURL,org_hyperlinkBracketsRight
syn match org_hyperlinkBracketsLeft	contained "\[\{2}"     conceal
syn match org_hyperlinkURL				    contained "[^][]*\]\[" conceal
syn match org_hyperlinkBracketsRight	contained "\]\{2}"     conceal

syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \k\k\k>\)/
"<2003-09-16 Tue 12:00>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d>\)/
"<2003-09-16 Tue 12:00 +1d>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d [+-]\d\+\w>\)/
"<2003-09-16 Tue 12:00 +1d -1y>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d [+-]\d\+\w [+-]\d\+\w>\)/
"<2003-09-16 Tue 12:00-12:30>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d-\d\d:\d\d>\)/

"<2003-09-16 Tue>--<2003-09-16 Tue>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \k\k\k>--<\d\d\d\d-\d\d-\d\d \k\k\k>\)/
"<2003-09-16 Tue 12:00>--<2003-09-16 Tue 12:00>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d>--<\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d>\)/

"[2003-09-16 Tue]
syn match org_timestamp_inactive /\(\[\d\d\d\d-\d\d-\d\d \k\k\k\]\)/
"[2003-09-16 Tue 12:00]
syn match org_timestamp_inactive /\(\[\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d\]\)/

"[2003-09-16 Tue 12:00 +1d]
syn match org_timestamp_inactive /\(\[\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d [+-]\d\+\w\]\)/
"[2003-09-16 Tue 12:00 +1d -1y]
syn match org_timestamp_inactive /\(\[\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d [+-]\d\+\w [+-]\d\+\w\]\)/

"[2003-09-16 Tue]--[2003-09-16 Tue]
syn match org_timestamp_inactive /\(\[\d\d\d\d-\d\d-\d\d \k\k\k\]--\[\d\d\d\d-\d\d-\d\d \k\k\k\]\)/
"[2003-09-16 Tue 12:00]--[2003-09-16 Tue 12:00]
syn match org_timestamp_inactive /\(\[\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d\]--\[\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d\]\)/

hi default link org_timestamp @org.timestamp.active
hi default link org_timestamp_inactive @org.timestamp.inactive

hi default link @org.agenda.day Statement
hi default link @org.agenda.today @org.bold
hi default link @org.agenda.weekend @org.bold
hi default link @org.agenda.header Comment
hi default link @org.agenda.separator Comment
hi default @org.agenda.tag gui=bold cterm=bold

hi default link org_hyperlink @org.hyperlink

let s:concealends = ''
let s:conceal = luaeval('require("orgmode.config").org_hide_emphasis_markers')
if s:conceal
    let s:concealends = ' concealends'
endif

function s:markup_start(marker, ...) abort
    let items = ['\s', '(', '-', "'", '"', '{']
    let alternative = get(a:, 1, '')
    if a:0 == 0
        let items += [a:marker, '^']
    endif
    return '#\('.join(items, '\|').'\)\zs'.a:marker.alternative.'#'
endfunction

function s:markup_end(marker) abort
    let items = ['$', '\s', ')', '-', '\}', "'", '"', ':', ';', '!', '\\', '\[', ',', '\.', '?'] + [a:marker]
    return '#'.a:marker.'\ze\('.join(items, '\|').'\)#'
endfunction

exe 'syntax region org_bold      matchgroup=org_bold_delimiter       start='.s:markup_start('\*', '\|^\*\ze[^ \*]').' end='.s:markup_end('\*').' keepend oneline contains=@Spell' . s:concealends
exe 'syntax region org_italic    matchgroup=org_italic_delimiter     start='.s:markup_start('\/').'    end='.s:markup_end('\/').' keepend oneline contains=@Spell' . s:concealends
exe 'syntax region org_underline matchgroup=org_underline_delimiter  start='.s:markup_start('_').'     end='.s:markup_end('_').'  keepend oneline contains=@Spell' . s:concealends
exe 'syntax region org_code      matchgroup=org_code_delimiter       start='.s:markup_start('\~').'    end='.s:markup_end('\~').' keepend oneline contains=@Spell' . s:concealends
exe 'syntax region org_verbatim  matchgroup=org_verbatim_delimiter   start='.s:markup_start('=').'     end='.s:markup_end('=').'  keepend oneline contains=@Spell' . s:concealends
exe 'syntax region org_strike    matchgroup=org_strike_delimiter     start='.s:markup_start('+').'     end='.s:markup_end('+').'  keepend oneline contains=@Spell' . s:concealends

hi link org_bold_delimiter org_bold
hi link org_italic_delimiter org_italic
hi link org_underline_delimiter org_underline
hi link org_code_delimiter org_code
hi link org_verbatim_delimiter org_verbatim
hi link org_strike_delimiter org_strike

hi def org_bold      term=bold      cterm=bold      gui=bold
hi def org_italic    term=italic    cterm=italic    gui=italic
hi def org_underline term=underline cterm=underline gui=underline
hi def org_strike    term=strikethrough cterm=strikethrough gui=strikethrough
hi def link org_code     String
hi def link org_verbatim String

syntax match org_hyperlink	"\[\{2}[^][]*\(\]\[[^][]*\)\?\]\{2}" contains=org_hyperlinkBracketsLeft,org_hyperlinkURL,org_hyperlinkBracketsRight
syntax match org_hyperlinkBracketsLeft	contained "\[\{2}"     conceal
syntax match org_hyperlinkURL				    contained "[^][]*\]\[" conceal
syntax match org_hyperlinkBracketsRight	contained "\]\{2}"     conceal
hi def link org_hyperlink Underlined

"
" Timestamps: {{{1
"<2003-09-16>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?>\)/
"<2003-09-16 12:00>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \d\d:\d\d\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?>\)/
"<2003-09-16 Tue>
"<2003-09-16 Sáb>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \k\k\k\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?>\)/
"<2003-09-16 Tue 12:00>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?>\)/
"<2003-09-16 Tue 12:00-12:30>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d-\d\d:\d\d\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?>\)/

"<2003-09-16 Tue>--<2003-09-16 Tue>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \k\k\k>--<\d\d\d\d-\d\d-\d\d \k\k\k>\)/
"<2003-09-16 Tue 12:00>--<2003-09-16 Tue 12:00>
syn match org_timestamp /\(<\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d>--<\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d>\)/

syn match org_timestamp /\(<%%(diary-float.\+>\)/

"[2003-09-16]
syn match org_timestamp_inactive /\(\[\d\d\d\d-\d\d-\d\d\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?]\)/
"[2003-09-16 Tue]
syn match org_timestamp_inactive /\(\[\d\d\d\d-\d\d-\d\d \k\k\k\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?\]\)/
"[2003-09-16 Tue 12:00]
syn match org_timestamp_inactive /\(\[\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?\(\s\+[+\-\.]\?[+\-]\d\+[hdmwy]\)\?\]\)/

"[2003-09-16 Tue]--[2003-09-16 Tue]
syn match org_timestamp_inactive /\(\[\d\d\d\d-\d\d-\d\d \k\k\k\]--\[\d\d\d\d-\d\d-\d\d \k\k\k\]\)/
"[2003-09-16 Tue 12:00]--[2003-09-16 Tue 12:00]
syn match org_timestamp_inactive /\(\[\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d\]--\[\d\d\d\d-\d\d-\d\d \k\k\k \d\d:\d\d\]\)/

syn match org_timestamp_inactive /\(\[%%(diary-float.\+\]\)/

hi def link org_timestamp PreProc
hi def link org_timestamp_inactive Comment

" Deadline And Schedule: {{{1
syn match org_deadline_scheduled /\<\(DEADLINE\|SCHEDULED\|CLOSED\)\>:/
hi def link org_deadline_scheduled PreProc

" Comments: {{{1
syntax match org_comment /^\s*#\s.*/ contains=@Spell
hi def link org_comment Comment

" Bullet Lists: {{{1
" Ordered Lists:
" 1. list item
" 1) list item
" a. list item
" a) list item
syn match org_list_ordered "^\s*\(\a\|\d\+\)[.)]\ze\(\s\|$\)" nextgroup=org_list_item
hi def link org_list_ordered Identifier

" Unordered Lists:
" - list item
" * list item
" + list item
" + and - don't need a whitespace prefix
syn match org_list_unordered "^\(\s*[-+]\|\s\+\*\)\ze\(\s\|$\)" nextgroup=org_list_item
hi def link org_list_unordered Identifier

" Definition Lists:
" - Term :: expl.
" 1) Term :: expl.
syntax match org_list_def /.*\s\+::/ contained
hi def link org_list_def PreProc

syntax match org_list_item /.*$/ contained contains=org_bold,org_italic,org_underline,org_code,org_verbatim,org_strike,@Spell

" Block Delimiters: {{{1
syntax case ignore
syntax match  org_block_delimiter /^\s*#+\(BEGIN_\|begin_\).*/
syntax match  org_block_delimiter /^\s*#+\(END_\|end_\).*/
syntax match  org_key_identifier  /^#+[^ ]*:/
syntax match  org_title           /^#+\(TITLE\|title\):.*/  contains=org_key_identifier
hi def link org_block_delimiter Comment
hi def link org_key_identifier  Comment
hi def link org_title           Title

" Block Markup: {{{1
" we consider all BEGIN/END sections as 'verbatim' blocks (inc. 'quote', 'verse', 'center')
" except 'example' and 'src' which are treated as 'code' blocks.
" Note: the non-standard '>' prefix is supported for quotation lines.
" Note: the '^:.*" rule must be defined before the ':PROPERTIES:' one below.
" TODO: http://vim.wikia.com/wiki/Different_syntax_highlighting_within_regions_of_a_file
syntax match  org_verbatim /^\s*>.*/
syntax match  org_code     /^\s*:.*/

syntax region org_verbatim start="^\s*#+\(BEGIN_\|begin_\).*"      end="^\s*#+\(END_\|end_\).*"      keepend contains=org_block_delimiter
syntax region org_code     start="^\s*#+\(BEGIN_SRC\|begin_src\)"     end="^\s*#+\(END_SRC\|end_src\)"     keepend contains=org_block_delimiter
syntax region org_code     start="^\s*#+\(BEGIN_EXAMPLE\|begin_example\)" end="^\s*#+\(END_EXAMPLE\|end_example\)" keepend contains=org_block_delimiter

" Properties: {{{1
syn region Error matchgroup=org_properties_delimiter start=/^\s*:PROPERTIES:\s*$/ end=/^\s*:END:\s*$/ contains=org_property keepend
syn match org_property /^\s*:[^\t :]\+:\s\+[^\t ]/ contained contains=org_property_value
syn match org_property_value /:\s\zs.*/ contained
hi def link org_properties_delimiter PreProc
hi def link org_property             Statement
hi def link org_property_value       Constant
" Break down subtasks
syntax match org_subtask_number /\[\d*\/\d*]/ contained
syntax match org_subtask_percent /\[\d*%\]/ contained
syntax match org_subtask_number_all /\[\(\d\+\)\/\1\]/ contained
syntax match org_subtask_percent_100 /\[100%\]/ contained

hi def link org_subtask_number String
hi def link org_subtask_percent String
hi def link org_subtask_percent_100 Identifier
hi def link org_subtask_number_all Identifier

" vi: ft=vim:tw=80:sw=4:ts=4:fdm=marker

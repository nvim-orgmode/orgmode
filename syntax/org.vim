" Bigger part of syntax borrowed from https://github.com/jceb/vim-orgmode

if exists('b:current_syntax')
  finish
endif

lua require('orgmode.colors.highlights').define_highlights()
let s:ts_highlight = luaeval('require("orgmode.config"):ts_highlights_enabled()')
if !s:ts_highlight
  lua require('orgmode.org.syntax').add_todo_keywords_to_spellgood()
  runtime syntax/org_legacy.vim
endif

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

let s:highlight_latex = luaeval('require("orgmode.config").org_highlight_latex_and_related')

if s:highlight_latex == 'native'
  unlet! b:current_syntax
  runtime! syntax/tex.vim
elseif s:highlight_latex == 'entities'
  syntax include @orgmodeLatex syntax/tex.vim
  unlet! b:current_syntax
  syntax region org_latex matchgroup=NONE start="^\s*\\begin{.*}$" end="^\s*\\end{.*}$" keepend contains=@orgmodeLatex
  syntax region org_latex matchgroup=NONE start="^\s*\\begin{.*}$" end="^\s*\\end{.*}$" keepend contains=@orgmodeLatex
  syntax region org_latex matchgroup=NONE start="\S\zs\$\|\$\S\@="  end="\S\zs\$\|\$\S\@="  keepend oneline contains=@orgmodeLatex
  syntax region org_latex matchgroup=NONE start="\$\$\|\$\$\@="  end="\$\$\|\$\$\@="  keepend oneline contains=@orgmodeLatex
  syntax region org_latex matchgroup=NONE start="\\)\|\\(\@="  end="\\)\|\\(\@="  keepend oneline contains=@orgmodeLatex
  syntax region org_latex matchgroup=NONE start="\\\]\|\\\[\@="  end="\\\]\|\\\[\@="  keepend oneline contains=@orgmodeLatex
endif

let b:current_syntax = 'org'

" vi: ft=vim:tw=80:sw=4:ts=4:fdm=marker

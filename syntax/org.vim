" Bigger part of syntax borrowed from https://github.com/jceb/vim-orgmode

if exists('b:current_syntax')
  finish
endif

lua require('orgmode.colors.highlights').define_highlights()
let s:concealends = ''
let s:conceal = luaeval('require("orgmode.config").org_hide_emphasis_markers')
if s:conceal
  let s:concealends = ' concealends'
endif
exe 'syntax region org_bold      matchgroup=org_bold_delimiter       start="\S\zs\*\|\*\S\@="  end="\S\zs\*\|\*\S\@="  keepend oneline contains=@Spell' . s:concealends
exe 'syntax region org_italic    matchgroup=org_italic_delimiter     start="\S\zs\/\|\/\S\@="  end="\S\zs\/\|\/\S\@="  keepend oneline contains=@Spell' . s:concealends
exe 'syntax region org_underline matchgroup=org_underline_delimiter  start="\S\zs_\|_\S\@="    end="\S\zs_\|_\S\@="    keepend oneline contains=@Spell' . s:concealends
exe 'syntax region org_code      matchgroup=org_code_delimiter       start="\S\zs\~\|\~\S\@="  end="\S\zs\~\|\~\S\@="  keepend oneline contains=@Spell' . s:concealends
exe 'syntax region org_verbatim  matchgroup=org_verbatim_delimiter   start="\S\zs=\|=\S\@="    end="\S\zs=\|=\S\@="    keepend oneline contains=@Spell' . s:concealends
exe 'syntax region org_strike    matchgroup=org_strike_delimiter     start="\S\zs+\|+\S\@="    end="\S\zs+\|+\S\@="    keepend oneline contains=@Spell' . s:concealends

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

let s:ts_highlight = luaeval('require("orgmode.config"):ts_highlights_enabled()')
if !s:ts_highlight
    runtime syntax/org_legacy.vim
endif

" Hyperlinks: {{{1
syntax match org_hyperlink	"\[\{2}[^][]*\(\]\[[^][]*\)\?\]\{2}" contains=org_hyperlinkBracketsLeft,org_hyperlinkURL,org_hyperlinkBracketsRight
syntax match org_hyperlinkBracketsLeft	contained "\[\{2}"     conceal
syntax match org_hyperlinkURL				    contained "[^][]*\]\[" conceal
syntax match org_hyperlinkBracketsRight	contained "\]\{2}"     conceal
hi def link org_hyperlink Underlined


syntax match org_list_checkbox /^\s*-\s\+\zs\[[ X-]]\ze/
hi def link org_list_checkbox     PreProc

hi org_hide_leading_stars ctermfg=0 guifg=bg

syntax spell toplevel

lua require("orgmode.org.syntax").load_code_blocks()

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

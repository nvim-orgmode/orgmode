" Bigger part of syntax borrowed from https://github.com/jceb/vim-orgmode

if exists('b:current_syntax')
  finish
endif

lua require('orgmode.colors.highlights').define_highlights()
lua require('orgmode.org.syntax').add_todo_keywords_to_spellgood()
let s:ts_highlight = luaeval('require("orgmode.config"):ts_highlights_enabled()')
if !s:ts_highlight
  runtime syntax/org_legacy.vim
endif

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

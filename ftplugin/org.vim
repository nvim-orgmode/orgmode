if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

lua require('orgmode.config'):setup_mappings('org')
lua require('orgmode.config'):setup_mappings('text_objects')

function! OrgmodeFoldText()
  return luaeval('require("orgmode.org.indent").foldtext()')
endfunction

function! OrgmodeOmni(findstart, base)
  return luaeval('require("orgmode.org.autocompletion.omni")(_A[1], _A[2])', [a:findstart, a:base])
endfunction

function! OrgmodeFormatExpr()
  return luaeval('require("orgmode.org.format")()')
endfunction

setlocal nomodeline
setlocal fillchars+=fold:\ 
setlocal foldmethod=expr
setlocal foldexpr=nvim_treesitter#foldexpr()
setlocal foldtext=OrgmodeFoldText()
setlocal formatexpr=OrgmodeFormatExpr()
setlocal foldlevel=0
setlocal omnifunc=OrgmodeOmni
setlocal commentstring=#\ %s
inoreabbrev <silent><buffer> :today: <C-R>=luaeval("require('orgmode.objects.date').today():to_wrapped_string(true)")<CR>
inoreabbrev <silent><buffer> :now: <C-R>=luaeval("require('orgmode.objects.date').now():to_wrapped_string(true)")<CR>

" The versions of the date abbreviations prefixed with 'i' produce inactive
" dates and timestamps rather than active ones like the non-prefixed
" abbreviations
inoreabbrev <silent><buffer> :itoday: <C-R>=luaeval("require('orgmode.objects.date').today():to_wrapped_string(false)")<CR>
inoreabbrev <silent><buffer> :inow: <C-R>=luaeval("require('orgmode.objects.date').now():to_wrapped_string(false)")<CR>

command! -buffer OrgDiagnostics lua require('orgmode.org.diagnostics').print()

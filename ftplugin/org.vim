if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

lua require('orgmode.config'):setup_mappings('org')
lua require('orgmode.config'):setup_mappings('text_objects')

function! OrgmodeFoldExpr()
  return luaeval('require("orgmode.org.indent").foldexpr()')
endfunction

function! OrgmodeFoldText()
  return luaeval('require("orgmode.org.indent").foldtext()')
endfunction

function OrgmodeOmni(findstart, base)
  return luaeval('require("orgmode.org.autocompletion.omni")(_A[1], _A[2])', [a:findstart, a:base])
endfunction

function OrgmodeFormatExpr()
  return luaeval('require("orgmode.org.format")()')
endfunction

setlocal fillchars+=fold:\ 
setlocal foldmethod=expr
setlocal foldexpr=OrgmodeFoldExpr()
setlocal foldtext=OrgmodeFoldText()
setlocal formatexpr=OrgmodeFormatExpr()
setlocal foldlevel=0
setlocal omnifunc=OrgmodeOmni
setlocal commentstring=#\ %s
inoreabbrev <silent><buffer> :today: <<C-R>=luaeval("require('orgmode.objects.date').today():to_string()")<CR>>
inoreabbrev <silent><buffer> :now: <<C-R>=luaeval("require('orgmode.objects.date').now():to_string()")<CR>>

command! -buffer OrgDiagnostics lua require('orgmode.org.diagnostics').print()

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

lua require('orgmode.config'):setup_mappings('org')

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

setlocal foldmethod=expr
setlocal foldexpr=OrgmodeFoldExpr()
setlocal foldtext=OrgmodeFoldText()
setlocal formatexpr=OrgmodeFormatExpr()
setlocal foldlevel=0
setlocal omnifunc=OrgmodeOmni
setlocal commentstring=#\ %s
inoreabbrev <silent><buffer> :today: <<C-R>=luaeval("require('orgmode.objects.date').today():to_string()")<CR>>
inoreabbrev <silent><buffer> :now: <<C-R>=luaeval("require('orgmode.objects.date').now():to_string()")<CR>>
xnoremap <silent><buffer> ih :<C-U>lua require("orgmode.org.motions").inner_heading()<CR>
onoremap <silent><buffer> ih :normal vih<CR>
xnoremap <silent><buffer> ah :<C-U>lua require("orgmode.org.motions").around_heading()<CR>
onoremap <silent><buffer> ah :normal vah<CR>
xnoremap <silent><buffer> ir :<C-U>lua require("orgmode.org.motions").inner_subtree()<CR>
onoremap <silent><buffer> ir :normal vir<CR>
xnoremap <silent><buffer> ar :<C-U>lua require("orgmode.org.motions").around_subtree()<CR>
onoremap <silent><buffer> ar :normal var<CR>
xnoremap <silent><buffer> 0h :<C-U>lua require("orgmode.org.motions").inner_heading_from_root()<CR>
onoremap <silent><buffer> 0h :normal v0h<CR>
xnoremap <silent><buffer> 0H :<C-U>lua require("orgmode.org.motions").around_heading_from_root()<CR>
onoremap <silent><buffer> 0H :normal v0H<CR>
xnoremap <silent><buffer> 0r :<C-U>lua require("orgmode.org.motions").inner_subtree_from_root()<CR>
onoremap <silent><buffer> 0r :normal v0r<CR>
xnoremap <silent><buffer> 0R :<C-U>lua require("orgmode.org.motions").around_subtree_from_root()<CR>
onoremap <silent><buffer> 0R :normal v0R<CR>

function! OrgmodeFoldExpr()
  return luaeval('require("orgmode.org.indent").foldexpr()')
endfunction

function! OrgmodeIndentExpr()
  return luaeval('require("orgmode.org.indent").indentexpr()')
endfunction

setlocal foldmethod=expr
setlocal foldexpr=OrgmodeFoldExpr()
setlocal foldtext=getline(v:foldstart)
setlocal indentexpr=OrgmodeIndentExpr()
setlocal foldlevel=0
setlocal nolisp
setlocal nosmartindent
setlocal autoindent

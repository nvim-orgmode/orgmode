function! OrgmodeIndentExpr()
  return luaeval('require("orgmode.org.indent").indentexpr()')
endfunction

setlocal indentexpr=OrgmodeIndentExpr()
setlocal nolisp
setlocal nosmartindent
setlocal autoindent

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

function! OrgmodeIndentExpr()
  return luaeval('require("orgmode.org.indent").indentexpr()')
endfunction

setlocal indentexpr=OrgmodeIndentExpr()
setlocal nolisp
setlocal nosmartindent
setlocal autoindent

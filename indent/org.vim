if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

function! OrgmodeFoldExpr()
  return luaeval('require("orgmode.org.indent").foldexpr()')
endfunction

function! OrgmodeIndentExpr()
  return luaeval('require("orgmode.org.indent").indentexpr()')
endfunction

function! OrgmodeFoldText()
  return luaeval('require("orgmode.org.indent").foldtext()')
endfunction

setlocal indentexpr=OrgmodeIndentExpr()
setlocal nolisp
setlocal nosmartindent
setlocal autoindent

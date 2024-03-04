if vim.b.did_indent then
  return
end
---@diagnostic disable-next-line: inject-field
vim.b.did_indent = true

vim.bo.indentexpr = 'v:lua.require("orgmode.org.indent").indentexpr()'
vim.bo.lisp = false
vim.bo.smartindent = false
vim.bo.autoindent = true
vim.b.undo_indent = table.concat({
  'setlocal indentexpr<',
  'lisp<',
  'smartindent<',
  'autoindent<',
}, ' ')

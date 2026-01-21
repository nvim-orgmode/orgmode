---@type vim.lsp.Config
return {
  cmd = require('orgmode.lsp.server'),
  filetypes = { 'org' },
}

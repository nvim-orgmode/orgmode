require('orgmode.config'):setup_mappings('org')
require('orgmode.config'):setup_mappings('text_objects')

-- options
vim.opt_local.modeline = false
vim.opt_local.fillchars:append('fold: ')
vim.opt_local.foldmethod = 'expr'
vim.opt_local.foldexpr = 'nvim_treesitter#foldexpr()'
vim.opt_local.foldtext = 'v:lua.require("orgmode.org.indent").foldtext()'
vim.opt_local.formatexpr = 'v:lua.require("orgmode.org.format")()'
vim.opt_local.foldlevel = 0
vim.opt_local.commentstring = '# %s'
vim.opt_local.omnifunc = 'function! OrgmodeOmni(findstart, base)'
  .. 'return luaeval(\'require("orgmode.org.autocompletion.omni")(_A[1], _A[2])\', [a:findstart, a:base])'
  .. 'endfunction'

-- abbreviations
vim.cmd(
  'inoreabbrev <silent><buffer> :today: <C-R>=luaeval("require(\'orgmode.objects.date\').today():to_wrapped_string(true)")<CR>'
)
vim.cmd(
  'inoreabbrev <silent><buffer> :now: <C-R>=luaeval("require(\'orgmode.objects.date\').now():to_wrapped_string(true)")<CR>'
)

-- The versions of the date abbreviations prefixed with 'i' produce inactive
-- dates and timestamps rather than active ones like the non-prefixed
-- abbreviations
vim.cmd(
  'inoreabbrev <silent><buffer> :itoday: <C-R>=luaeval("require(\'orgmode.objects.date\').today():to_wrapped_string(false)")<CR>'
)
vim.cmd(
  'inoreabbrev <silent><buffer> :inow: <C-R>=luaeval("require(\'orgmode.objects.date\').now():to_wrapped_string(false)")<CR>'
)

-- user commands
vim.api.nvim_buf_create_user_command(0, 'OrgDiagnostics', function()
  require('orgmode.org.diagnostics').print()
end, {})

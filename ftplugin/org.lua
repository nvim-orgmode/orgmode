if vim.b.did_ftplugin or vim.b.org_tmp_edit_window then
  return
end
---@diagnostic disable-next-line: inject-field
vim.b.did_ftplugin = true

local config = require('orgmode.config')

vim.treesitter.start()

local bufnr = vim.api.nvim_get_current_buf()

config:setup_mappings('org', bufnr)
config:setup_mappings('text_objects', bufnr)
config:setup_foldlevel()

if config.org_startup_indented then
  require('orgmode.ui.virtual_indent'):new(bufnr):attach()
end

vim.bo.modeline = false
vim.opt_local.fillchars:append('fold: ')
vim.opt_local.foldmethod = 'expr'
vim.opt_local.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
if config.ui.folds.colored then
  vim.opt_local.foldtext = ''
else
  vim.opt_local.foldtext = 'v:lua.require("orgmode.org.indent").foldtext()'
end
vim.opt_local.formatexpr = 'v:lua.require("orgmode.org.format")()'
vim.opt_local.omnifunc = 'v:lua.orgmode.omnifunc'
vim.opt_local.commentstring = '# %s'
vim.bo.indentkeys = ('%s,%s'):format(vim.bo.indentkeys, '=~end_src,=~end_example,<:>')

_G.orgmode.omnifunc = function(findstart, base)
  return require('orgmode').completion:omnifunc(findstart, base)
end

local abbreviations = {
  [':today:'] = "require('orgmode.objects.date').today():to_wrapped_string(true)",
  [':now:'] = "require('orgmode.objects.date').now():to_wrapped_string(true)",
  [':itoday:'] = "require('orgmode.objects.date').today():to_wrapped_string(false)",
  [':inow:'] = "require('orgmode.objects.date').now():to_wrapped_string(false)",
}

for abbrev, cmd in pairs(abbreviations) do
  vim.cmd.inoreabbrev(('<silent><buffer> %s <C-R>=luaeval("%s")<CR>'):format(abbrev, cmd))
end

for _, char in ipairs({ '*', '=', '/', '+', '~', '_' }) do
  vim.keymap.set('x', 'i' .. char, ':<C-u>normal! T' .. char .. 'vt' .. char .. '<CR>', { buffer = true })
  vim.keymap.set('o', 'i' .. char, ':normal vi' .. char .. '<CR>', { buffer = true })
  vim.keymap.set('x', 'a' .. char, ':<C-u>normal! F' .. char .. 'vf' .. char .. '<CR>', { buffer = true })
  vim.keymap.set('o', 'a' .. char, ':normal va' .. char .. '<CR>', { buffer = true })
end

if config.org_highlight_latex_and_related then
  vim.bo[bufnr].syntax = 'ON'
end

vim.b.undo_ftplugin = table.concat({
  'setlocal',
  'commentstring<',
  'foldmethod<',
  'modeline<',
  'foldtext<',
  'foldlevel<',
  'foldexpr<',
  'formatexpr<',
  'omnifunc<',
  'indentkeys<',
  '| unlet! b:org_tmp_edit_window',
}, ' ')

-- Manually attach Snacks.image module to ensure that images are shown.
-- Snacks usually handles this automatically, but if Orgmode plugin is loaded after Snacks, it will not pick it up.
if vim.tbl_get(_G, 'Snacks', 'image', 'config', 'enabled') and vim.tbl_get(_G, 'Snacks', 'image', 'config', 'doc', 'enabled') then
  require('snacks.image.doc').attach(bufnr)
end

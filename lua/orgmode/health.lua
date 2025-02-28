local h = vim.health

local M = {}

function M.check()
  h.start('Orgmode')
  M.check_has_treesitter()
  M.check_setup()
  M.check_shellslash()
end

function M.check_has_treesitter()
  local ts = require('orgmode.utils.treesitter.install')
  if ts.not_installed() then
    return h.error('Treesitter grammar is not installed. Run `:Org install_treesitter_grammar` to install it.')
  end
  if ts.outdated() then
    return h.error('Treesitter grammar is out of date. Run `:Org install_treesitter_grammar` to update it.')
  end
  return h.ok('Treesitter grammar installed')
end

function M.check_setup()
  local config = require('orgmode.config')
  local orgmode = require('orgmode')

  if not orgmode.is_setup_called() then
    h.warn('Setup not called')
  else
    h.ok('Setup called')
  end

  if not config.org_agenda_files or #config.org_agenda_files == 0 then
    h.warn('No agenda files configured. Set `org_agenda_files` in your config.')
  else
    h.ok('`org_agenda_files` configured')
  end
  if not config.org_default_notes_file or config.org_default_notes_file == '' then
    h.warn('No default notes file configured. Set `org_default_notes_file` in your config.')
  else
    h.ok('`org_default_notes_file` configured')
  end
end

function M.check_shellslash()
  if vim.fn.has('win32') ~= 1 then
    return
  end
  if not vim.opt.shellslash:get() then
    h.warn(
      '`shellslash` is not set. This might cause issues with file paths in links. Set `vim.opt.shellslash = true` in your configuration.'
    )
  else
    h.ok('`shellslash` is set')
  end
end

return M

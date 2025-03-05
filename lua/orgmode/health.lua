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
  local version_info = ts.get_version_info()
  if not version_info.installed then
    return h.error('Treesitter grammar is not installed. Run `:Org install_treesitter_grammar` to install it.')
  end

  if not version_info.install_location then
    local list = vim.tbl_map(function(parser)
      return ('- `%s`'):format(parser)
    end, version_info.conflicting_parsers)
    return h.error(
      ('Installed org parser found in incorrect location. Run `:Org install_treesitter_grammar` to install it in correct location and remove the conflicting parsers from these locations:\n%s'):format(
        table.concat(list, '\n')
      )
    )
  end

  if version_info.outdated then
    return h.error('Treesitter grammar is out of date. Run `:Org install_treesitter_grammar` to update it.')
  end

  if version_info.version_mismatch then
    return h.warn(
      ('Treesitter grammar version mismatch (installed %s, required %s). Run `:Org install_treesitter_grammar` to update it.'):format(
        version_info.installed_version,
        version_info.required_version
      )
    )
  end

  if #version_info.conflicting_parsers > 0 then
    local list = vim.tbl_map(function(parser)
      return ('- `%s`'):format(parser)
    end, version_info.conflicting_parsers)
    return h.warn(
      ('Conflicting org parser(s) found in these locations:\n%s\nRemove them to avoid conflicts.'):format(
        table.concat(list, '\n')
      )
    )
  end

  return h.ok(('Treesitter grammar installed (version %s)'):format(version_info.installed_version))
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

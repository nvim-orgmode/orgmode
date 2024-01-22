local M = {}
---
---@class OrgMinPlugin A plugin to download and register on the package path
---@alias OrgPluginName string The plugin name, will be used as part of the git clone destination
---@alias OrgPluginUrl string The git url at which a plugin is located, can be a path. See https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols for details
---@alias OrgMinPlugins table<OrgPluginName, OrgPluginUrl>

-- Gets the current directory of this file
local base_root_path = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h')
---Gets the root directory of the minimal init and if path is specified appends the given path to the root allowing for
---subdirectories within the current cwd
---@param path string? The additional path to append to the root, not required
---@return string root The root path suffixed with the path provided or an empty suffix if none was given
function M.root(path)
  return base_root_path .. '/.deps/' .. (path or '')
end

---Downloads a plugin from a given url and registers it on the 'runtimepath'
---@param plugin_name OrgPluginName
---@param plugin_url OrgPluginUrl
function M.load_plugin(plugin_name, plugin_url)
  local package_root = M.root('plugins/')
  local install_destination = package_root .. plugin_name
  vim.opt.runtimepath:append(install_destination)

  if not vim.loop.fs_stat(package_root) then
    vim.fn.mkdir(package_root, 'p')
  end

  -- If the plugin install path already exists, we don't need to clone it again.
  if not vim.loop.fs_stat(install_destination) then
    print(string.format('>> Downloading plugin "%s" to "%s"', plugin_name, install_destination))
    vim.fn.system({
      'git',
      'clone',
      '--depth=1',
      plugin_url,
      install_destination,
    })
    if vim.v.shell_error > 0 then
      error(
        string.format('>> Failed to clone plugin: "%s" to "%s"!', plugin_name, install_destination),
        vim.log.levels.ERROR
      )
    end
  end
end

---Do the initial setup. Downloads plugins, ensures the minimal init does not pollute the filesystem by keeping
---everything self contained to the CWD of the minimal init file. Run prior to running tests, reproducing issues, etc.
---@param plugins? OrgMinPlugins
function M.setup(plugins)
  vim.opt.packpath = {} -- Empty the package path so we use only the plugins specified
  vim.opt.runtimepath:append(M.root('.min')) -- Ensure the runtime detects the root min dir

  -- Install required plugins
  if plugins ~= nil then
    for plugin_name, plugin_url in pairs(plugins) do
      M.load_plugin(plugin_name, plugin_url)
    end
  end

  vim.env.XDG_CONFIG_HOME = M.root('xdg/config')
  vim.env.XDG_DATA_HOME = M.root('xdg/data')
  vim.env.XDG_STATE_HOME = M.root('xdg/state')
  vim.env.XDG_CACHE_HOME = M.root('xdg/cache')

  local std_paths = {
    'cache',
    'data',
    'config',
  }

  for _, std_path in pairs(std_paths) do
    vim.fn.mkdir(vim.fn.stdpath(std_path), 'p')
  end

  -- NOTE: Cleanup the xdg cache on exit so new runs of the minimal init doesn't share any previous state, e.g. shada
  vim.api.nvim_create_autocmd('VimLeave', {
    callback = function()
      vim.fn.delete(M.root('xdg'), 'rf')
    end,
  })
end

M.setup({
  plenary = 'https://github.com/nvim-lua/plenary.nvim.git',
  treesitter = 'https://github.com/nvim-treesitter/nvim-treesitter',
})
-- WARN: Do all plugin setup, test runs, reproductions, etc. AFTER calling setup with a list of plugins!
-- Basically, do all that stuff AFTER this line.

--## Set proper settings ##
-- Register Orgmode on the runtimepath, base_root_path is the directory where this file exists
vim.opt.runtimepath:prepend(vim.fn.fnamemodify(base_root_path, ':h'))
vim.opt.termguicolors = true
vim.opt.swapfile = false
vim.opt.expandtab = true -- Accommodates some deep nesting in indent_spec.lua
vim.cmd.language('en_US.utf-8')
vim.env.TZ = 'Europe/London'
vim.g.mapleader = ','

-- NOTE: This is a workaround to get the clipboard working in the CI environment
-- where the clipboard provider does not exist.
if vim.env.CI == 'true' then
  vim.g.org_custom_clipboard = {}
  vim.g.clipboard = {
    name = 'org_custom_clipboard',
    copy = {
      ['+'] = function(lines, regtype)
        vim.g.org_custom_clipboard = { lines, regtype }
      end,
      ['*'] = function(lines, regtype)
        vim.g.org_custom_clipboard = { lines, regtype }
      end,
    },
    paste = {
      ['+'] = function()
        return vim.g.org_custom_clipboard or {}
      end,
      ['*'] = function()
        return vim.g.org_custom_clipboard or {}
      end,
    },
  }
end

require('orgmode').setup_ts_grammar()
require('nvim-treesitter.configs').setup({
  ensure_installed = { 'org' },
  sync_install = true,
})

require('orgmode').setup({
  org_agenda_files = { base_root_path .. '/plenary/fixtures/*' },
  org_default_notes_file = base_root_path .. '/plenary/fixtures/refile.org',
})

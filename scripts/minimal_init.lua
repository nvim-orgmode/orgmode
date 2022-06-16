vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

local package_root = '/tmp/nvim/site/pack'
local install_path = package_root .. '/packer/start/packer.nvim'

local function load_plugins()
  require('packer').startup({
    {
      'wbthomason/packer.nvim',
      { 'nvim-treesitter/nvim-treesitter' },
      { 'kristijanhusak/orgmode.nvim', branch = 'master' },
    },
    config = {
      package_root = package_root,
      compile_path = install_path .. '/plugin/packer_compiled.lua',
    },
  })
end

_G.load_config = function()
  require('orgmode').setup_ts_grammar()
  require('nvim-treesitter.configs').setup({
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = { 'org' },
    },
  })

  vim.cmd([[packadd nvim-treesitter]])
  vim.cmd([[runtime plugin/nvim-treesitter.lua]])
  vim.cmd([[TSUpdateSync org]])

  -- Close packer after install
  if vim.bo.filetype == 'packer' then
    vim.api.nvim_win_close(0, true)
  end

  require('orgmode').setup()

  -- Reload current file if it's org file to reload tree-sitter
  if vim.bo.filetype == 'org' then
    vim.cmd([[edit!]])
  end
end

if vim.fn.isdirectory(install_path) == 0 then
  vim.fn.system({ 'git', 'clone', 'https://github.com/wbthomason/packer.nvim', install_path })
  load_plugins()
  require('packer').sync()
  vim.cmd([[autocmd User PackerCompileDone ++once lua load_config()]])
else
  load_plugins()
  load_config()
end

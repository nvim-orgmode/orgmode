set rtp+=.
set rtp+=./plenary.nvim
set rtp+=./nvim-treesitter
set termguicolors
set noswapfile
language en_US.utf-8
runtime plugin/plenary.vim
runtime plugin/nvim-treesitter.lua
let mapleader = ','
set shada="NONE"

lua << EOF
require('orgmode').setup_ts_grammar()
require('nvim-treesitter.configs').setup({})

require('orgmode').setup({
  org_agenda_files = { vim.fn.getcwd() .. '/tests/plenary/fixtures/*' },
  org_default_notes_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/refile.org',
})
EOF

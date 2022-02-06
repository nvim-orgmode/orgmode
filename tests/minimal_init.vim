set rtp+=.
set rtp+=./plenary.nvim
set rtp+=./nvim-treesitter
set termguicolors
set noswapfile
runtime plugin/plenary.vim
runtime plugin/nvim-treesitter.vim
let mapleader = ','

lua << EOF
require('orgmode').setup_ts_grammar()
require('nvim-treesitter.configs').setup({})

require('orgmode').setup({
  org_agenda_files = { vim.fn.getcwd() .. '/tests/plenary/fixtures/*' },
  org_default_notes_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/refile.org',
})
EOF

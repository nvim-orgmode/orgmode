set rtp+=.
set rtp+=./plenary.nvim
set rtp+=./nvim-treesitter
set termguicolors
set noswapfile
runtime plugin/plenary.vim
runtime plugin/nvim-treesitter.vim
let mapleader = ','

lua << EOF
require('nvim-treesitter.configs').setup({})

local parser_config = require('nvim-treesitter.parsers').get_parser_configs()

parser_config.org = {
  install_info = {
    url = 'https://github.com/milisims/tree-sitter-org',
    revision = 'f110024d539e676f25b72b7c80b0fd43c34264ef',
    files = {'src/parser.c', 'src/scanner.cc'},
  },
  filetype = 'org',
}

require('orgmode').setup({
  org_agenda_files = { vim.fn.getcwd() .. '/tests/plenary/fixtures/*' },
  org_default_notes_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/refile.org',
})
EOF

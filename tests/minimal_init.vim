set rtp+=.
set rtp+=./plenary.nvim
set rtp+=./nvim-treesitter
set termguicolors
set noswapfile
runtime plugin/plenary.vim
runtime plugin/nvim-treesitter.vim

lua << EOF
require('nvim-treesitter.configs').setup({})

local parser_config = require('nvim-treesitter.parsers').get_parser_configs()

parser_config.org = {
  install_info = {
    url = 'https://github.com/kristijanhusak/tree-sitter-org',
    revision = 'main',
    files = {'src/parser.c', 'src/scanner.cc'},
  },
  filetype = 'org',
}

require('orgmode').setup({
  org_agenda_files = vim.fn.getcwd() .. '/tests/plenary/fixtures/*',
  org_default_notes_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/refile.org',
})
EOF

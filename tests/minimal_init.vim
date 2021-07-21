set rtp+=.
set rtp+=./plenary.nvim
set rtp+=./nvim-treesitter
set termguicolors
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
EOF

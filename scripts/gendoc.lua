vim.cmd([[set rtp+=./plenary.nvim]])
vim.cmd([[set rtp+=./mini.nvim]])
local minidoc = require('mini.doc')

if _G.MiniDoc == nil then
  minidoc.setup()
end
minidoc.generate(
  {
    'lua/orgmode/api/init.lua',
    'lua/orgmode/api/file.lua',
    'lua/orgmode/api/headline.lua',
    'lua/orgmode/api/position.lua',
  },
  'doc/orgmode_api.txt'
)
vim.cmd([[qa!]])

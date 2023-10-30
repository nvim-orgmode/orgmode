local files = {
  'lua/orgmode/api/init.lua',
  'lua/orgmode/api/file.lua',
  'lua/orgmode/api/headline.lua',
  'lua/orgmode/api/agenda.lua',
  'lua/orgmode/api/position.lua',
}
local destination = 'doc/orgmode_api.txt'

vim.fn.system(('lemmy-help %s > %s'):format(table.concat(files, ' '), destination))
vim.cmd([[qa!]])

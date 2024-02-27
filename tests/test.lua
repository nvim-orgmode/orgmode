require('tests.minimal_init')
---@type string
local test_file = vim.v.argv[#vim.v.argv]
if test_file == '' or not test_file:find('tests/plenary/', nil, true) then
  test_file = 'tests/plenary'
  print('Running all tests at ' .. test_file)
else
  print('Individual Test File/Directory provided: ' .. test_file)
end

require('plenary.test_harness').test_directory(test_file, {
  minimal_init = 'tests/minimal_init.lua',
  sequential = true,
})

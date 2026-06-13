-- Ensure that tree-sitter grammar can be correctly installed, exit early on error
vim.opt.runtimepath:prepend(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h'))
local ok, err = pcall(function()
  return require('orgmode.utils.treesitter.install').install()
end)
if not ok then
  print(vim.inspect(err), '\n')
  return os.exit(1)
end

-- Do not run tests on Windows, just ensure that tree-sitter grammar can be installed.
if vim.fn.has('win32') > 0 then
  return os.exit(0)
end

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

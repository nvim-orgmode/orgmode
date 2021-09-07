local function load_file(path)
  vim.cmd(string.format('e %s', path))
  vim.wait(10000, function()
    return require('orgmode.parser.files').loaded
  end, 5)
  vim.cmd(string.format('e %s', path))
end

return {
  load_file = load_file,
}

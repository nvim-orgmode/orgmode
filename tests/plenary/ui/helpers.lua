local function load_file(path)
  vim.cmd(string.format('e %s', path))
  require('orgmode.parser.files').ensure_loaded()
  vim.cmd(string.format('e %s', path))
end

return {
  load_file = load_file,
}

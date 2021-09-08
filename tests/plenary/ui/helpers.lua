local function load_file(path)
  vim.cmd(string.format('e %s', path))
  require('orgmode.parser.files').ensure_loaded()
  vim.cmd(string.format('e %s', path))
end

local function load_file_content(content)
  require('orgmode.parser.files').loaded = false
  local fname = vim.fn.tempname() .. '.org'
  vim.fn.writefile(content or {}, fname)
  load_file(fname)
end

return {
  load_file = load_file,
  load_file_content = load_file_content,
}

local Files = require('orgmode.parser.files')
local function load_file(path)
  vim.cmd(string.format('e %s', path))
  Files.ensure_loaded()
  vim.wait(500, function()
    return Files.get(path) ~= nil
  end, 5)
  vim.cmd(string.format('e %s', path))
end

local function load_file_content(content)
  Files.loaded = false
  local fname = vim.fn.tempname() .. '.org'
  vim.fn.writefile(content or {}, fname)
  load_file(fname)
end

return {
  load_file = load_file,
  load_file_content = load_file_content,
}

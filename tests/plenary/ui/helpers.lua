local Files = require('orgmode.parser.files')
local function load_file(path)
  vim.cmd(string.format('e %s', path))
  vim.wait(5000, function()
    return Files.get(path) ~= nil
  end, 5)
  vim.cmd(string.format('e %s', path))
  return path
end

local function load_file_content(content)
  local fname = vim.fn.tempname() .. '.org'
  vim.fn.writefile(content or {}, fname)
  return load_file(fname)
end

return {
  load_file = load_file,
  load_file_content = load_file_content,
}

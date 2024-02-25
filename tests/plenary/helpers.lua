local OrgFile = require('orgmode.files.file')
local orgmode = require('orgmode')

local function load_file(path)
  vim.cmd(string.format('e %s', path))
  return orgmode.files:get(path)
end

local function create_file(lines)
  local fname = vim.fn.tempname() .. '.org'
  vim.fn.writefile(lines or {}, fname)
  return load_file(fname)
end

---@return OrgFile
local function create_agenda_file(lines, config)
  local fname = vim.fn.tempname() .. '.org'
  vim.fn.writefile(lines or {}, fname)

  local cfg = vim.tbl_extend('force', {
    org_agenda_files = { vim.fn.fnamemodify(fname, ':p:h') .. '/**/*' },
  }, config or {})
  local org = orgmode.setup(cfg)
  org:init()
  return load_file(fname)
end

---@return OrgFile
local function create_file_instance(lines, filename)
  local file = OrgFile:new({
    filename = filename or vim.fn.tempname() .. '.org',
    lines = lines,
  })
  file:parse()
  return file
end

return {
  create_file = create_file,
  create_file_instance = create_file_instance,
  create_agenda_file = create_agenda_file,
}

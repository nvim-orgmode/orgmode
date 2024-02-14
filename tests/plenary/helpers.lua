local OrgFile = require('orgmode.files.file')
local orgmode = require('orgmode')

local function load_file(path)
  vim.cmd(string.format('e %s', path))
  orgmode.files:get(path)
  vim.cmd(string.format('e %s', path))
  return path
end

local function load_file_content(content)
  local fname = vim.fn.tempname() .. '.org'
  vim.fn.writefile(content or {}, fname)
  return load_file(fname)
end

local function setup_org_agenda(filename, config)
  local cfg = vim.tbl_extend('force', {
    org_agenda_files = { vim.fn.fnamemodify(filename, ':p:h') .. '/**/*' },
  }, config or {})
  local org = orgmode.setup(cfg)
  org:init()
  return org
end

---@return OrgFile
local function load_as_agenda_file(content, config)
  local fname = vim.fn.tempname() .. '.org'
  vim.fn.writefile(content or {}, fname)
  local org = setup_org_agenda(fname, config)
  local filepath = load_file(fname)
  return org.files:get(filepath)
end

---@return OrgFile
local function file_from_content(content, filename)
  return OrgFile:new({
    filename = filename or vim.fn.tempname() .. '.org',
    lines = content,
  })
end

return {
  load_file = load_file,
  load_file_content = load_file_content,
  file_from_content = file_from_content,
  load_as_agenda_file = load_as_agenda_file,
  setup_org_agenda = setup_org_agenda,
}

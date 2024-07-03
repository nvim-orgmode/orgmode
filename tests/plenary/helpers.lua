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

---@param fixtures {filename: string, content: string[] }[]
---@param config table?
---@return table
local function create_agenda_files(fixtures, config)
  -- NOTE: content is only 1 line for 1 file
  local temp_fname = vim.fn.tempname()
  local temp_dir = vim.fn.fnamemodify(temp_fname, ':p:h')
  -- clear temp dir
  vim.fn.delete(temp_dir .. '/*', 'rf')
  local files = {}
  local agenda_files = {}
  for _, fixture in pairs(fixtures) do
    local fname = temp_dir .. '/' .. fixture.filename
    fname = vim.fn.fnamemodify(fname, ':p')
    if fname then
      local dir = vim.fn.fnamemodify(fname, ':p:h')
      vim.fn.mkdir(dir, 'p')
      vim.fn.writefile(fixture.content, fname)
      files[fixture.filename] = fname
      table.insert(agenda_files, fname)
    end
  end
  local cfg = vim.tbl_extend('force', {
    org_agenda_files = agenda_files,
  }, config or {})
  local org = orgmode.setup(cfg)
  org:init()
  return files
end

return {
  load_file = load_file,
  create_file = create_file,
  create_file_instance = create_file_instance,
  create_agenda_file = create_agenda_file,
  create_agenda_files = create_agenda_files,
}

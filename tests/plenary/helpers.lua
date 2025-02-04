local OrgFile = require('orgmode.files.file')
local orgmode = require('orgmode')

local M = {}

---Temporarily change a variable.
---@param ctx table<string, any>
---@param name string
---@param value any
---@param inner fun()
function M.with_var(ctx, name, value, inner)
  local old = ctx[name]
  ctx[name] = value
  local ok, err = pcall(inner)
  ctx[name] = old
  assert(ok, err)
end

---Temporarily change the working directory.
---@param new_path string
---@param inner fun()
function M.with_cwd(new_path, inner)
  local old_path = vim.fn.getcwd()
  vim.cmd.cd(new_path)
  local ok, err = pcall(inner)
  vim.cmd.cd(old_path)
  assert(ok, err)
end

---@param path string
function M.load_file(path)
  vim.cmd.edit(path)
  return orgmode.files:get(path)
end

---@param lines string[]
function M.create_file(lines)
  local fname = vim.fn.tempname() .. '.org'
  vim.fn.writefile(lines or {}, fname)
  return M.load_file(fname)
end

---@param lines string[]
---@param config? table
---@return OrgFile
function M.create_agenda_file(lines, config)
  local fname = vim.fn.tempname() .. '.org'
  vim.fn.writefile(lines or {}, fname)

  local cfg = vim.tbl_extend('force', {
    org_agenda_files = { vim.fn.fnamemodify(fname, ':p:h') .. '/**/*' },
  }, config or {})
  local org = orgmode.setup(cfg)
  org:init()
  return M.load_file(fname)
end

---@param lines string[]
---@param filename string
---@return OrgFile
function M.create_file_instance(lines, filename)
  local file = OrgFile:new({
    filename = filename or vim.fn.tempname() .. '.org',
    lines = lines,
  })
  file:parse()
  return file
end

---@param fixtures {filename: string, content: string[] }[]
---@param config? table
---@return table
function M.create_agenda_files(fixtures, config)
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

return M

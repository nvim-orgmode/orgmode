local Files = require('orgmode.parser.files')
local OrgFile = require('orgmode.api.file')

local OrgApi = {}

---@param name? string|string[] specific file names to return (absolute path). If ommitted, returns all loaded files
---@return OrgFile|OrgFile[]
function OrgApi.load(name)
  vim.validate({
    name = { name, { 'string', 'table' }, true },
  })
  if not Files.loaded then
    Files.load()
  end
  Files.ensure_loaded()
  if not name then
    return vim.tbl_map(function(file)
      return OrgFile._build_from_internal_file(file)
    end, Files.all())
  end

  if type(name) == 'string' then
    local file = Files.get(name)
    return OrgFile._build_from_internal_file(file)
  end

  if type(name) == 'table' then
    local list = {}
    for _, file in ipairs(Files.all()) do
      if file.filename == name then
        table.insert(list, OrgFile._build_from_internal_file(file))
      end
    end

    return list
  end
end

--- Get current org buffer file
---@return OrgFile
function OrgApi.current()
  if vim.bo.filetype ~= 'org' then
    error('Not an org buffer.')
  end
  local name = vim.api.nvim_buf_get_name(0)
  return OrgApi.load(name)
end

return OrgApi

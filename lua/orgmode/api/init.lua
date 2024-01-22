---@diagnostic disable: invisible
local OrgFile = require('orgmode.api.file')
local orgmode = require('orgmode')

local OrgApi = {}

---@param name? string|string[] specific file names to return (absolute path). If ommitted, returns all loaded files
---@return OrgApiFile|OrgApiFile[]
function OrgApi.load(name)
  vim.validate({
    name = { name, { 'string', 'table' }, true },
  })
  if not name then
    return vim.tbl_map(function(file)
      return OrgFile._build_from_internal_file(file)
    end, orgmode.files:all())
  end

  if type(name) == 'string' then
    local file = orgmode.files:get(name)
    return OrgFile._build_from_internal_file(file)
  end

  if type(name) == 'table' then
    local list = {}
    for _, file in ipairs(orgmode.files:all()) do
      if file.filename == name then
        table.insert(list, OrgFile._build_from_internal_file(file))
      end
    end

    return list
  end
  error('Invalid argument to OrgApi.load')
end

--- Get current org buffer file
---@return OrgApiFile
function OrgApi.current()
  if vim.bo.filetype ~= 'org' then
    error('Not an org buffer.')
  end
  local name = vim.api.nvim_buf_get_name(0)
  return OrgApi.load(name)
end

return OrgApi

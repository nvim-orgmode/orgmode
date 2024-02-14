---@diagnostic disable: invisible
local OrgFile = require('orgmode.api.file')
local OrgHeadline = require('orgmode.api.headline')
local orgmode = require('orgmode')

---@class OrgApiRefileOpts
---@field source OrgApiHeadline
---@field destination OrgApiFile | OrgApiHeadline

---@class OrgApi
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

---Refile headline to another file or headline
---If executed from capture buffer, it will close the capture buffer
---@param opts OrgApiRefileOpts
---@return boolean
function OrgApi.refile(opts)
  vim.validate({
    source = { opts.source, 'table' },
    destination = { opts.destination, 'table' },
  })

  if getmetatable(opts.source) ~= OrgHeadline then
    error('Source must be an OrgApiHeadline')
  end

  local is_file = getmetatable(opts.destination) == OrgFile
  local is_headline = getmetatable(opts.destination) == OrgHeadline

  if not is_file and not is_headline then
    error('Destination must be an OrgApiFile or OrgApiHeadline')
  end

  local refile_opts = {
    item = opts.source._section,
    lines = opts.source._section:get_lines(),
  }

  if is_file then
    refile_opts.file = opts.destination.filename
  else
    refile_opts.file = opts.destination.file.filename
    refile_opts.headline = opts.destination.title
  end
  local source_bufnr = vim.fn.bufnr(opts.source.file.filename) or -1

  orgmode.capture:_refile_to(refile_opts)

  if source_bufnr > -1 and vim.b[source_bufnr].org_capture then
    orgmode.capture:kill()
  end

  return true
end

return OrgApi

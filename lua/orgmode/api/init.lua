---@diagnostic disable: invisible
local OrgFile = require('orgmode.api.file')
local OrgHeadline = require('orgmode.api.headline')
local orgmode = require('orgmode')
local Promise = require('orgmode.utils.promise')
local utils = require('orgmode.utils')

---@class OrgApiRefileOpts
---@field source OrgApiHeadline
---@field destination OrgApiFile | OrgApiHeadline

---@class OrgApi
local OrgApi = {}

---@param name? string|string[] specific file names to return (absolute path). If ommitted, returns all loaded files
---@return OrgApiFile|OrgApiFile[]
function OrgApi.load(name)
  vim.validate('name', name, { 'string', 'table' }, true)
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
  error('Invalid argument to OrgApi.load', 0)
end

--- Get current org buffer file
---@return OrgApiFile
function OrgApi.current()
  if vim.bo.filetype ~= 'org' then
    error('Not an org buffer.', 0)
  end
  local name = vim.api.nvim_buf_get_name(0)
  return OrgApi.load(name)
end

---Refile headline to another file or headline
---If executed from capture buffer, it will close the capture buffer
---@param opts OrgApiRefileOpts
---@return OrgPromise<boolean>
function OrgApi.refile(opts)
  vim.validate('source', opts.source, 'table')
  vim.validate('destination', opts.destination, 'table')

  if getmetatable(opts.source) ~= OrgHeadline then
    error('Source must be an OrgApiHeadline', 0)
  end

  local is_file = getmetatable(opts.destination) == OrgFile
  local is_headline = getmetatable(opts.destination) == OrgHeadline

  if not is_file and not is_headline then
    error('Destination must be an OrgApiFile or OrgApiHeadline', 0)
  end

  local refile_opts = {
    source_file = opts.source._section.file,
    source_headline = opts.source._section,
  }

  if is_file then
    refile_opts.destination_file = opts.destination._file
  else
    refile_opts.destination_file = opts.destination._section.file
    refile_opts.destination_headline = opts.destination._section
  end

  local source_bufnr = utils.get_buffer_by_filename(opts.source.file.filename)
  local is_capture = source_bufnr > -1 and vim.b[source_bufnr].org_capture
  if is_capture then
    local capture_window = orgmode.capture._windows[vim.b[source_bufnr].org_capture_window_id]
    if capture_window then
      refile_opts.template = capture_window.template
      refile_opts.capture_window = capture_window
    end
  end

  return Promise.resolve()
    :next(function()
      if is_capture then
        return orgmode.capture:_refile_from_capture_buffer(refile_opts)
      end
      return orgmode.capture:_refile_from_org_file(refile_opts)
    end)
    :next(function()
      return true
    end)
end

--- Insert a link to a given location at the current cursor position
---
--- The expected format is
--- <protocol>:<location>::<in_file_location>
---
--- If <in_file_location> is *<headline>, <headline> is used as prefilled description for the link.
--- If <protocol> is id, this format can also be used to pass a prefilled description.
--- @param link_location string
--- @return OrgPromise<boolean>
function OrgApi.insert_link(link_location)
  return orgmode.links:insert_link(link_location)
end

return OrgApi

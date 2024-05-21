---@diagnostic disable: invisible
local OrgFile = require('orgmode.api.file')
local OrgHeadline = require('orgmode.api.headline')
local Hyperlinks = require('orgmode.org.hyperlinks')
local Link = require('orgmode.org.hyperlinks.link')
local orgmode = require('orgmode')

---@class OrgApiRefileOpts
---@field source OrgApiHeadline
---@field destination OrgApiFile | OrgApiHeadline

---@class OrgApi
---@field load fun(name?: string|string[]): OrgApiFile|OrgApiFile[]
---@field current fun(): OrgApiFile
---@field refile fun(opts: OrgApiRefileOpts)
---@field insert_link fun(link_location: string): boolean
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
    source_file = opts.source._section.file,
    source_headline = opts.source._section,
  }

  if is_file then
    refile_opts.destination_file = opts.destination._file
  else
    refile_opts.destination_file = opts.destination._section.file
    refile_opts.destination_headline = opts.destination._section
  end

  local source_bufnr = vim.fn.bufnr(opts.source.file.filename) or -1
  local is_capture = source_bufnr > -1 and vim.b[source_bufnr].org_capture

  if is_capture and orgmode.capture._window then
    refile_opts.template = orgmode.capture._window.template
  end

  if is_capture then
    orgmode.capture:_refile_from_capture_buffer(refile_opts)
  else
    orgmode.capture:_refile_from_org_file(refile_opts)
  end

  return true
end

--- Insert a link to a given location at the current cursor position
--- @param link_location string
--- @return boolean
function OrgApi.insert_link(link_location)
  local selected_link = Link:new(link_location)
  local desc = selected_link.url:get_target_value()
  if selected_link.url:is_id() then
    local id_link = ('id:%s'):format(selected_link.url:get_id())
    desc = link_location:gsub('^' .. vim.pesc(id_link) .. '%s+', '')
    link_location = id_link
  end

  local link_description = vim.trim(vim.fn.OrgmodeInput('Description: ', desc or ''))

  link_location = '[' .. vim.trim(link_location) .. ']'

  if link_description ~= '' then
    link_description = '[' .. link_description .. ']'
  end

  local insert_from
  local insert_to
  local target_col = #link_location + #link_description + 2

  -- check if currently on link
  local link, position = Hyperlinks.get_link_under_cursor()
  if link and position then
    insert_from = position.from - 1
    insert_to = position.to + 1
    target_col = target_col + position.from
  else
    local colnr = vim.fn.col('.')
    insert_from = colnr
    insert_to = colnr + 1
    target_col = target_col + colnr
  end

  local linenr = vim.fn.line('.') or 0
  local curr_line = vim.fn.getline(linenr)
  local new_line = string.sub(curr_line, 0, insert_from)
    .. '['
    .. link_location
    .. link_description
    .. ']'
    .. string.sub(curr_line, insert_to, #curr_line)

  vim.fn.setline(linenr, new_line)
  vim.fn.cursor(linenr, target_col)
end

return OrgApi

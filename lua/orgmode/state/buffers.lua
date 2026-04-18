---@class OrgBuffers
---@field private _bufs table<string, number>
local OrgBuffers = {
  _bufs = {},
}

function OrgBuffers.init()
  local all_buffers = vim.api.nvim_list_bufs()
  local valid_buffers = {}
  for _, bufnr in ipairs(all_buffers) do
    local valid_buffer_name = OrgBuffers.get_valid_buffer_name(bufnr)
    if valid_buffer_name then
      valid_buffers[valid_buffer_name] = bufnr
    end
  end

  OrgBuffers._bufs = valid_buffers
  return OrgBuffers
end

---Return the buffer number for a given filename
---If filename has org extension (.org or .org_archive), it will return the buffer number directly
---If filename does not have org extension, it will try to find the buffer number and return
---@param filename string absolute path to file
function OrgBuffers.get_buffer_by_filename(filename)
  local resolved_filename = OrgBuffers._resolve_filename(filename)

  if OrgBuffers._bufs[resolved_filename] then
    return OrgBuffers._bufs[resolved_filename]
  end

  local bufnr = vim.fn.bufnr(resolved_filename)

  if bufnr < 0 then
    return -1
  end

  -- If filename does not have an org extension, return the buffer only if it has correct filetype
  if not OrgBuffers._is_valid_file_name(resolved_filename) then
    if vim.bo[bufnr].filetype == 'org' then
      return bufnr
    end

    return -1
  end

  -- bufnr() can return wrong buffer number in cases when there are multiple files matching, for example:
  -- * `/path/to/orgfiles/todos.org`
  -- * `/path/to/orgfiles/todos.org_archive`
  -- Doing `bufnr('/path/to/orgfiles/todos.org')` can return buffer number for `/path/to/orgfiles/todos.org_archive`.
  -- Resolve the filename of the found buffer, and make sure it matches the resolved filename we are looking for
  -- If not, fallback to nvim_list_bufs
  local buffer_filename = OrgBuffers._resolve_filename(vim.api.nvim_buf_get_name(bufnr))

  if buffer_filename == resolved_filename then
    return OrgBuffers.add(bufnr)
  end

  local all_bufs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(all_bufs) do
    local valid_buffer_name = OrgBuffers.get_valid_buffer_name(buf)
    if valid_buffer_name and valid_buffer_name == resolved_filename then
      return OrgBuffers.add(buf)
    end
  end

  return -1
end

---Add the buffer to the list
---@param bufnr number
---@return number bufnr if the buffer is valid and added, -1 otherwise
function OrgBuffers.add(bufnr)
  local name = OrgBuffers.get_valid_buffer_name(bufnr)

  if name then
    OrgBuffers._bufs[name] = bufnr
    return bufnr
  end

  return -1
end

---Remove the buffer from the list
---@param bufnr number
function OrgBuffers.remove(bufnr)
  local name = OrgBuffers.get_valid_buffer_name(bufnr)

  if name and OrgBuffers._bufs[name] then
    OrgBuffers._bufs[name] = nil
  end
end

---Get valid buffer name if the buffer is an org file
---@param bufnr number
function OrgBuffers.get_valid_buffer_name(bufnr)
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  if not OrgBuffers._is_valid_file_name(bufname) then
    return nil
  end

  return OrgBuffers._resolve_filename(bufname)
end

---Resolve and normalize the filename
---@param filename string
---@return string
function OrgBuffers._resolve_filename(filename)
  return vim.fs.normalize(vim.fn.resolve(filename))
end

---Check if given filename has valid org extension
---@private
---@param filename string
function OrgBuffers._is_valid_file_name(filename)
  filename = filename or ''
  return filename:sub(-4) == '.org' or filename:sub(-12) == '.org_archive'
end

return OrgBuffers

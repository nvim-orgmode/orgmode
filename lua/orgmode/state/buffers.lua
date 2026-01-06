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
  local resolved_filename = vim.fn.resolve(filename)

  if OrgBuffers._bufs[resolved_filename] then
    return OrgBuffers._bufs[resolved_filename]
  end

  -- If filename does not have an org extension, try to find the buf number and return it if filetype is org
  if not OrgBuffers._is_valid_file_name(resolved_filename) then
    local bufnr = vim.fn.bufnr(resolved_filename)
    if bufnr > -1 and vim.bo[bufnr].filetype == 'org' then
      return bufnr
    end
  end

  return -1
end

---Add the buffer to the list
---@param bufnr number
function OrgBuffers.add(bufnr)
  local name = OrgBuffers.get_valid_buffer_name(bufnr)

  if name then
    OrgBuffers._bufs[name] = bufnr
  end
end

---Remove the buffer from the list
---@param bufnr number
function OrgBuffers.remove(bufnr)
  local name = vim.fn.resolve(vim.api.nvim_buf_get_name(bufnr))

  if OrgBuffers._bufs[name] then
    OrgBuffers._bufs[name] = nil
  end
end

---Get valid buffer name if the buffer is an org file
---@param bufnr number
function OrgBuffers.get_valid_buffer_name(bufnr)
  local name = vim.fn.resolve(vim.fn.bufname(bufnr))

  if OrgBuffers._is_valid_file_name(name) then
    return name
  end

  return nil
end

---Check if given filename has valid org extension
---@private
---@param filename string
function OrgBuffers._is_valid_file_name(filename)
  filename = filename or ''
  return filename:sub(-4) == '.org' or filename:sub(-12) == '.org_archive'
end

return OrgBuffers

---@class OrgBuffers
---@field private _bufs table<string, number>
---@field private _misses table<string, boolean>
---@field private _resolved table<string, string>
local OrgBuffers = {
  _bufs = {},
  _misses = {},
  _resolved = {},
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
  OrgBuffers._misses = {}
  OrgBuffers._setup_autocmds()
  return OrgBuffers
end

---Headline enumeration asks for the buffer of every agenda file thousands of
---times, and almost none of those files have a buffer, so misses are worth
---caching too. A miss only holds until a buffer for that name exists, and
---these are the events that can bring one into existence.
---@private
function OrgBuffers._setup_autocmds()
  local group = vim.api.nvim_create_augroup('org_buffers', { clear = true })

  -- FileType matters because a file without an org extension only counts once
  -- its filetype is set, which happens after the buffer already exists.
  vim.api.nvim_create_autocmd({ 'BufAdd', 'BufNew', 'BufFilePost', 'FileType' }, {
    group = group,
    callback = function(args)
      if not OrgBuffers.get_valid_buffer_name(args.buf) and vim.bo[args.buf].filetype ~= 'org' then
        return
      end
      OrgBuffers._forget(args.buf)
      OrgBuffers.add(args.buf)
      OrgBuffers._misses = {}
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    group = group,
    callback = function(args)
      OrgBuffers._forget(args.buf)
    end,
  })
end

---Drop every name mapped to `bufnr`. `remove` derives the name from the
---buffer, so on a rename it would clear the new name and the old one would
---stay reachable: a lookup for the old path would still resolve to this
---buffer, which now holds a different file.
---@private
---@param bufnr number
function OrgBuffers._forget(bufnr)
  for name, nr in pairs(OrgBuffers._bufs) do
    if nr == bufnr then
      OrgBuffers._bufs[name] = nil
    end
  end
end

---@private
---@param resolved_filename string
---@return number always -1
function OrgBuffers._miss(resolved_filename)
  OrgBuffers._misses[resolved_filename] = true
  return -1
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

  if OrgBuffers._misses[resolved_filename] then
    return -1
  end

  local bufnr = vim.fn.bufnr(resolved_filename)

  if bufnr < 0 then
    return OrgBuffers._miss(resolved_filename)
  end

  -- If filename does not have an org extension, return the buffer only if it has correct filetype
  if not OrgBuffers._is_valid_file_name(resolved_filename) then
    if vim.bo[bufnr].filetype == 'org' then
      return bufnr
    end

    return OrgBuffers._miss(resolved_filename)
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

  return OrgBuffers._miss(resolved_filename)
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
  local resolved = OrgBuffers._resolved[filename]
  if not resolved then
    resolved = vim.fs.normalize(vim.fn.resolve(filename))
    OrgBuffers._resolved[filename] = resolved
  end
  return resolved
end

---Check if given filename has valid org extension
---@private
---@param filename string
function OrgBuffers._is_valid_file_name(filename)
  filename = filename or ''
  return filename:sub(-4) == '.org' or filename:sub(-12) == '.org_archive'
end

return OrgBuffers

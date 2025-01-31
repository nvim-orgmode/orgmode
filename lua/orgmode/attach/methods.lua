local Promise = require('orgmode.utils.promise')
local config = require('orgmode.config')
local fileops = require('orgmode.attach.fileops')
local utils = require('orgmode.utils')

local M = {}

---@type table<OrgAttachMethod, fun(source: string, target: string): OrgPromise<boolean>>
local FILE_ATTACHERS = {
  mv = function(source, target)
    return fileops.rename(source, target)
  end,
  cp = function(source, target)
    if fileops.is_dir(source) then
      return fileops.copy_directory(source, target, {
        parents = false,
        keep_times = false,
        create_symlink = config.org_attach_copy_directory_create_symlink,
      })
    else
      return fileops.copy_file(source, target, { excl = true, ficlone = true, ficlone_force = false })
    end
  end,
  ln = function(source, target)
    return fileops.hardlink(source, target)
  end,
  lns = function(source, target)
    return fileops.symlink(source, target, { dir = false, junction = false, exist_ok = false })
  end,
}

---Look up method of attaching a file.
---
---Splitting the method lookup from the actual method is only advantageous for
---`OrgAttachCore.attach_many`, where it lets us avoid doing the same lookup
---for every file.
---
---@param method OrgAttachMethod
---@return fun(source: string, target: string): OrgPromise<boolean> success
function M.get_file_attacher(method)
  return FILE_ATTACHERS[method] or error('unknown org_attach_method: ' .. tostring(method))
end

---Attach a resource from the Internet to current the outline node.
---
---Errors if it would overwrite an existing filename.
---
---@param url string
---@param target string
---@return OrgPromise<boolean> success
function M.attach_url(url, target)
  return fileops.download_file(url, target, { exist_ok = false })
end

---Attach a buffer's contents to the current outline node.
---
---Errors if it would overwrite an existing filename.
---
---@param bufnr integer
---@param target string
---@return OrgPromise<boolean> success
function M.attach_buffer(bufnr, target)
  local data = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
  return utils.writefile(target, data, { excl = true }):next(function()
    return true
  end)
end

return M

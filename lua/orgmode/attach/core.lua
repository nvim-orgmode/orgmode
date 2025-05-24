local AttachNode = require('orgmode.attach.node')
local EventManager = require('orgmode.events')
local Promise = require('orgmode.utils.promise')
local config = require('orgmode.config')
local fileops = require('orgmode.attach.fileops')
local utils = require('orgmode.utils')

---@class OrgAttachCore
---@field files OrgFiles
---@field links OrgLinks
local AttachCore = {}
AttachCore.__index = AttachCore

---@param opts {files:OrgFiles, links:OrgLinks}
function AttachCore.new(opts)
  local data = {
    files = opts and opts.files,
    links = opts and opts.links,
  }
  return setmetatable(data, AttachCore)
end

---Get the current attachment node.
---
---@return OrgAttachNode
function AttachCore:get_current_node()
  return AttachNode.at_cursor(self.files:get_current_file())
end

---Return the directory associated with the current outline node.
---
---First check for DIR property, then ID property.
---`org_attach_use_inheritance' determines whether inherited
---properties also will be considered.
---
---If an ID property is found the default mechanism using that ID
---will be invoked to access the directory for the current entry.
---Note that this method returns the directory as declared by ID or
---DIR even if the directory doesn't exist in the filesystem.
---
---@param node OrgAttachNode
---@param no_fs_check? boolean if true, return the directory even if it doesn't
---                            exist
---@return string|nil attach_dir
function AttachCore:get_dir_or_nil(node, no_fs_check)
  local dir = node:get_dir()
  return dir and (no_fs_check or fileops.is_dir(dir)) and dir or nil
end

---Return the directory associated with the current outline node.
---
---First check for DIR property, then ID property.
---`org_attach_use_inheritance' determines whether inherited
---properties also will be considered.
---
---If an ID property is found the default mechanism using that ID
---will be invoked to access the directory for the current entry.
---Note that this method returns the directory as declared by ID or
---DIR even if the directory doesn't exist in the filesystem.
---
---@param node OrgAttachNode
---@param no_fs_check? boolean if true, return the directory even if it doesn't
---                            exist
---@return string attach_dir
function AttachCore:get_dir(node, no_fs_check)
  return self:get_dir_or_nil(node, no_fs_check) or error('No attachment directory for this node')
end

---@alias orgmode.attach.core.new_method 'id' | 'dir'

---Return existing or new directory associated with the current outline node.
---
---`org_attach_preferred_new_method` decides how to attach new directory if
---neither ID nor DIR property exist.
---
---If the attachment by some reason cannot be created an error will be raised.
---
---@param node OrgAttachNode
---@param method fun(): OrgPromise<orgmode.attach.core.new_method>
---@param new_dir fun(): OrgPromise<string | nil>
---@return OrgPromise<string>
function AttachCore:get_dir_or_create(node, method, new_dir)
  local dir = self:get_dir_or_nil(node) -- free `is_dir()` check
  if dir then
    return Promise.resolve(dir)
  end
  return method()
    :next(function(chosen_method)
      if chosen_method == 'id' then
        return node:id_dir_get_or_create()
      elseif chosen_method == 'dir' then
        return new_dir():next(function(chosen_dir)
          if not chosen_dir or chosen_dir == '' then
            error('No attachment selected')
          end
          return node:set_dir(chosen_dir)
        end)
      else
        error(('unknown method: %s'):format(chosen_method))
      end
    end)
    ---@param chosen_dir string
    :next(function(chosen_dir)
      local mode = 493 -- octal 0755 as decimal
      return fileops.make_dir(chosen_dir, { mode = mode, parents = true, exist_ok = true }):next(function()
        return chosen_dir
      end)
    end)
end

---@class orgmode.attach.core.set_directory.opts
---@field do_copy fun(old: string, new: string): OrgPromise<boolean>
---@field do_delete fun(old: string): OrgPromise<boolean>

---Set the DIR node property and ask to move files there.
---
---The property defines the directory that is used for attachments
---of the entry.
---
---@param node OrgAttachNode
---@param new_dir string
---@param opts orgmode.attach.core.set_directory.opts
---@return OrgPromise<string | nil> new_dir
function AttachCore:set_directory(node, new_dir, opts)
  local old_dir = self:get_dir(node, true)
  -- Ordering matters here: both `opts` should be evaluated before the
  -- operations (copy if desired, set_dir, delete if desired) start.
  ---@param do_copy? boolean
  return Promise.resolve(old_dir and new_dir and opts.do_copy(old_dir, new_dir)):next(function(do_copy)
    ---@param do_delete? boolean
    return Promise.resolve(old_dir and opts.do_delete(old_dir)):next(function(do_delete)
      if do_copy == nil or do_delete == nil then
        return
      end
      return Promise.resolve()
        :next(function()
          return do_copy
            and fileops.copy_directory(old_dir, new_dir, {
              parents = true,
              keep_times = true,
              create_symlink = config.org_attach_copy_directory_create_symlink,
            })
        end)
        :next(function()
          node:set_dir(new_dir)
        end)
        :next(function()
          return do_delete and fileops.remove_directory(old_dir, { recursive = true })
        end)
    end)
  end)
end

---Remove DIR node property.
---
---If attachment folder is changed due to removal of DIR-property
---ask to move attachments to new location and ask to delete old
---attachment folder.
---
---Change of attachment-folder due to unset might be if an ID
---property is set on the node, or if a separate inherited
---DIR-property exists (that is different from the unset one).
---
---@param node OrgAttachNode
---@param opts orgmode.attach.core.set_directory.opts
---@return OrgPromise<string | nil> new_dir
function AttachCore:unset_directory(node, opts)
  local old_dir = self:get_dir(node, true)
  node:set_dir()
  -- After removal, there might be a new DIR directory via inheritance.
  local new_dir = self:get_dir_or_nil(node, true)
  if not new_dir then
    -- There is no parent node with a DIR property. Switch back to ID-based
    -- directory.
    new_dir = node:id_dir_get_or_create()
  end
  -- Ordering matters here: both `opts` should be evaluated before the
  -- operations (copy if desired, delete if desired) start.
  ---@param do_copy? boolean
  return Promise.resolve(old_dir and new_dir and opts.do_copy(old_dir, new_dir)):next(function(do_copy)
    ---@param do_delete? boolean
    return Promise.resolve(old_dir and opts.do_delete(old_dir)):next(function(do_delete)
      if do_copy == nil or do_delete == nil then
        return
      end
      return Promise.resolve()
        :next(function()
          return do_copy
            and fileops.copy_directory(old_dir, new_dir, {
              parents = true,
              keep_times = true,
              create_symlink = config.org_attach_copy_directory_create_symlink,
            })
        end)
        :next(function()
          return do_delete and fileops.remove_directory(old_dir, { recursive = true })
        end)
    end)
  end)
end

---Turn the autotag on.
---
---If autotagging is disabled, this does nothing.
---
---@param node OrgAttachNode
---@return nil
function AttachCore:tag(node)
  node:add_auto_tag()
end

---Turn the autotag off.
---
---If autotagging is disabled, this does nothing.
---
---@param node OrgAttachNode
---@return nil
function AttachCore:untag(node)
  node:remove_auto_tag()
end

---Helper to the `attach_*()` functions.
---Like `vim.fs.basename()` but reject an empty string result.
---This also ignores trailing slashes, e.g.:
---* '/foo/bar' -> 'bar'
---* '/foo/' -> 'foo'
---* '/' -> error!
---@param path string
---@return string basename
local function basename_safe(path)
  local match = path:match('^(.*[^/])/*$')
  local basename = match and vim.fs.basename(match)
  return basename ~= '' and basename or error('cannot determine attachment name: ' .. path)
end

---@alias OrgAttachMethod 'cp' | 'mv' | 'ln' | 'lns'

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

---@param method OrgAttachMethod
---@return fun(source: string, target: string): OrgPromise<boolean> success
local function get_file_attacher(method)
  return FILE_ATTACHERS[method] or error('unknown org_attach_method: ' .. tostring(method))
end

---@class orgmode.attach.core.attach.opts
---@inlinedoc
---@field attach_method OrgAttachMethod
---@field set_dir_method fun(): OrgPromise<orgmode.attach.core.new_method>
---@field new_dir fun(): OrgPromise<string | nil>

---Move/copy/link file into attachment directory of the current outline node.
---
---@param node OrgAttachNode
---@param file string The file to attach
---@param opts orgmode.attach.core.attach.opts
---@return OrgPromise<string|nil> attachment_name
function AttachCore:attach(node, file, opts)
  if file == '' then
    utils.echo_warning('No attachment selected')
    return Promise.resolve()
  end
  local basename = basename_safe(file)
  local attach = get_file_attacher(opts.attach_method)
  return self:get_dir_or_create(node, opts.set_dir_method, opts.new_dir):next(function(attach_dir)
    local attach_file = vim.fs.joinpath(attach_dir, basename)
    return attach(file, attach_file):next(function(success)
      if not success then
        return nil
      end
      EventManager.dispatch(EventManager.event.AttachChanged:new(node, attach_dir))
      node:add_auto_tag()
      local link = self.links:store_link_to_attachment({ attach_dir = attach_dir, original = file })
      return Promise.new(function(resolve, reject)
        vim.schedule(function()
          local ok, err = pcall(vim.fn.setreg, vim.v.register, link)
          if ok then
            resolve(basename)
          else
            reject(err)
          end
        end)
      end)
    end)
  end)
end

---@class orgmode.attach.core.attach_buffer.opts
---@inlinedoc
---@field set_dir_method fun(): OrgPromise<orgmode.attach.core.new_method>
---@field new_dir fun(): OrgPromise<string | nil>

---Attach buffer's contents to current outline node.
---
---Throws a file-exists error if it would overwrite an existing filename.
---
---@param node OrgAttachNode
---@param bufnr integer
---@param opts orgmode.attach.core.attach_buffer.opts
---@return OrgPromise<string|nil> attachment_name
function AttachCore:attach_buffer(node, bufnr, opts)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local basename = basename_safe(bufname)
  return self:get_dir_or_create(node, opts.set_dir_method, opts.new_dir):next(function(attach_dir)
    local attach_file = vim.fs.joinpath(attach_dir, basename)
    local data = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
    return utils.writefile(attach_file, data, { excl = true }):next(function()
      EventManager.dispatch(EventManager.event.AttachChanged:new(node, attach_dir))
      node:add_auto_tag()
      -- Ignore all errors here, this is just to determine whether we can store
      -- a link to `bufname`.
      local bufname_exists = vim.uv.fs_stat(bufname)
      local link = self.links:store_link_to_attachment({
        attach_dir = attach_dir,
        original = bufname_exists and bufname or attach_file,
      })
      vim.fn.setreg(vim.v.register, link)
      return basename
    end)
  end)
end

---@class orgmode.attach.core.attach_many.result
---@field successes integer
---@field failures integer

---Move/copy/link many files into attachment directory.
---
---@param node OrgAttachNode
---@param files string[]
---@param opts orgmode.attach.core.attach.opts
---@return OrgPromise<orgmode.attach.core.attach_many.result> tally
function AttachCore:attach_many(node, files, opts)
  local attach = get_file_attacher(opts.attach_method)
  ---@type orgmode.attach.core.attach_many.result
  local initial_tally = { successes = 0, failures = 0 }
  if #files == 0 then
    return Promise.resolve(initial_tally)
  end
  return self:get_dir_or_create(node, opts.set_dir_method, opts.new_dir):next(function(attach_dir)
    return Promise
      .mapSeries(function(to_be_attached)
        local basename = basename_safe(to_be_attached)
        local attach_file = vim.fs.joinpath(attach_dir, basename)
        return attach(to_be_attached, attach_file):next(function(success)
          self.links:store_link_to_attachment({ attach_dir = attach_dir, original = to_be_attached })
          return success
        end)
      end, files)
      ---@param successes boolean[]
      :next(function(successes)
        EventManager.dispatch(EventManager.event.AttachChanged:new(node, attach_dir))
        node:add_auto_tag()
        ---@param tally orgmode.attach.core.attach_many.result
        ---@param success boolean
        ---@return orgmode.attach.core.attach_many.result tally
        return utils.reduce(successes, function(tally, success)
          if success then
            tally.successes = tally.successes + 1
          else
            tally.failures = tally.failures + 1
          end
          return tally
        end, initial_tally)
      end)
  end)
end

---@class orgmode.attach.core.attach_new.opts
---@inlinedoc
---@field set_dir_method fun(): OrgPromise<orgmode.attach.core.new_method>
---@field new_dir fun(): OrgPromise<string | nil>
---@field edit_bang boolean
---@field edit_mods table<string,any>

---Create a new attachment FILE for the current outline node.
---
---The attachment is opened via `:edit`. The command can be modified via
---`opts`.
---
---@param node OrgAttachNode
---@param name string
---@param opts orgmode.attach.core.attach_new.opts
---@return OrgPromise<string|nil> attachment_name
function AttachCore:attach_new(node, name, opts)
  if name == '' then
    utils.echo_warning('No attachment selected')
    return Promise.resolve()
  end
  return self:get_dir_or_create(node, opts.set_dir_method, opts.new_dir):next(function(attach_dir)
    local path = vim.fs.joinpath(attach_dir, name)
    --TODO: the emacs version doesn't run the hook here. Is this correct?
    EventManager.dispatch(EventManager.event.AttachChanged:new(node, attach_dir))
    node:add_auto_tag()
    ---@type vim.api.keyset.cmd
    return Promise.new(function(resolve, reject)
      local cmd = { cmd = 'edit', args = { path }, bang = opts.edit_bang, mods = opts.edit_mods }
      vim.schedule(function()
        local ok, err = pcall(vim.api.nvim_cmd, cmd, {})
        if ok then
          resolve(name)
        else
          reject(err)
        end
      end)
    end)
  end)
end

---Open the attachments directory via `vim.ui.open()`.
---
---@param attach_dir string the directory to open
---@return vim.SystemObj
function AttachCore:reveal(attach_dir)
  return assert(vim.ui.open(attach_dir))
end

---Open the attachments directory via `org_attach_visit_command`.
---
---@param attach_dir string the directory to open
---@return nil
function AttachCore:reveal_nvim(attach_dir)
  local command = config.org_attach_visit_command or 'edit'
  if type(command) == 'string' then
    vim.cmd[command](attach_dir)
  else
    command(attach_dir)
  end
end

---Open an attached file via `vim.ui.open()`.
---
---@param node OrgAttachNode
---@param name string name of the file to open
---@return vim.SystemObj
function AttachCore:open(name, node)
  local attach_dir = self:get_dir(node)
  local path = vim.fs.joinpath(attach_dir, name)
  EventManager.dispatch(EventManager.event.AttachOpened:new(node, path))
  return assert(vim.ui.open(path))
end

---Open an attached file via `:edit`.
---
---@param node OrgAttachNode
---@param name string name of the file to open
---@return nil
function AttachCore:open_in_vim(name, node)
  local attach_dir = self:get_dir(node)
  local path = vim.fs.joinpath(attach_dir, name)
  EventManager.dispatch(EventManager.event.AttachOpened:new(node, path))
  vim.cmd.edit(path)
end

---Delete a single attachment.
---
---@param node OrgAttachNode
---@param name string the name of the attachment to delete
---@return OrgPromise<nil>
function AttachCore:delete_one(node, name)
  if name == '' then
    utils.echo_warning('No attachment selected')
    return Promise.resolve()
  end
  local attach_dir = self:get_dir(node)
  local path = vim.fs.joinpath(attach_dir, name)
  return fileops.unlink(path):next(function()
    EventManager.dispatch(EventManager.event.AttachChanged:new(node, attach_dir))
    return nil
  end)
end

---Delete all attachments from the current outline node.
---
---This actually deletes the entire attachment directory. A safer way is to
---open the directory with `reveal` and delete from there.
---
---@param node OrgAttachNode
---@param recursive fun(): OrgPromise<boolean>
---@return OrgPromise<string> deleted_dir
function AttachCore:delete_all(node, recursive)
  local attach_dir = self:get_dir(node)
  -- A few synchronous FS operations here, can't really be avoided. The
  -- alternative would be to evaluate `recursive` before it's necessary.
  local uv = vim.uv or vim.loop
  local ok, errmsg, err = uv.fs_unlink(attach_dir)
  if ok then
    return Promise.resolve()
  elseif err ~= 'EISDIR' then
    return Promise.reject(errmsg)
  end
  ok, errmsg, err = uv.fs_rmdir(attach_dir)
  if ok then
    return Promise.resolve()
  elseif err ~= 'ENOTEMPTY' then
    return Promise.reject(errmsg)
  end
  return recursive():next(function(do_recursive)
    if not do_recursive then
      return Promise.reject(errmsg)
    end
    return fileops.remove_directory(attach_dir, { recursive = true }):next(function()
      EventManager.dispatch(EventManager.event.AttachChanged:new(node, attach_dir))
      node:remove_auto_tag()
      return attach_dir
    end)
  end)
end

---Return true if the directory contains any files without trailing `~` in
---their name. Trailing `~` is Emacs convention for swap files.
---
---@param directory string
---@return boolean
local function has_any_non_litter_files(directory)
  ---@param name string
  return fileops.iterdir(directory):any(function(name)
    return not vim.endswith(name, '~')
  end)
end

---Synchronize the current outline node with its attachments.
---
---Useful after files have been added/removed externally. The Option
---`org_attach_sync_delete_empty_dir` controls the behavior for empty
---attachment directories. (This ignores files whose name ends with
---a tilde `~`.)
---
---@param node OrgAttachNode
---@param delete_empty_dir fun(): OrgPromise<boolean>
---@return OrgPromise<string|nil> attach_dir_if_deleted
function AttachCore:sync(node, delete_empty_dir)
  local attach_dir = self:get_dir_or_nil(node)
  if not attach_dir then
    self:untag(node)
    return Promise.resolve()
  end
  EventManager.dispatch(EventManager.event.AttachChanged:new(node, attach_dir))
  local non_empty = has_any_non_litter_files(attach_dir)
  if non_empty then
    node:add_auto_tag()
    return Promise.resolve()
  else
    node:remove_auto_tag()
  end
  return delete_empty_dir():next(function(do_delete)
    if not do_delete then
      return Promise.resolve()
    end
    return fileops.remove_directory(attach_dir, { recursive = true }):next(function()
      return attach_dir
    end)
  end)
end

return AttachCore

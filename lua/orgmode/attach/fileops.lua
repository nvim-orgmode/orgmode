local Promise = require('orgmode.utils.promise')
local uv = vim.uv

---@param resolve fun(...)
---@param reject fun(...)
---@return fun(err: string?, success: boolean?)
local function uv_resolver(resolve, reject)
  return function(err, success)
    if err then
      reject(err)
    else
      resolve(success)
    end
  end
end

---Utility functions for dealing with files.
---This module currently is only used by `OrgAttach`. However, it is general
---enough that, if it is useful for other modules, that it could be moved to
---`utils`.
---
---IMPLEMENTATION NOTE: Every time we chain promises, we step out of fast-api
---mode and schedule another function. It is not clear what the performance
---implications are. A test run of copying a directory with 1000 files, this
---was reasonably fast and didn't block the editor.
local M = {}

--[[
-- libuv functions ported to use OrgPromise
--]]

---Like `vim.uv.fs_rename`, but returns a promise.
---@param path string
---@param new_path string
---@return OrgPromise<true> success
function M.rename(path, new_path)
  return Promise.new(function(resolve, reject)
    uv.fs_rename(path, new_path, uv_resolver(resolve, reject))
  end)
end

---Like `vim.uv.fs_copyfile`, but returns a promise.
---@param path string
---@param new_path string
---@param flags? integer | uv.fs_copyfile.flags_t
---@return OrgPromise<true> success
function M.copy_file(path, new_path, flags)
  return Promise.new(function(resolve, reject)
    uv.fs_copyfile(path, new_path, flags, uv_resolver(resolve, reject))
  end)
end

---Like `vim.uv.fs_link`, but returns a promise.
---@param path string
---@param new_path string
---@return OrgPromise<true> success
function M.hardlink(path, new_path)
  return Promise.new(function(resolve, reject)
    uv.fs_link(path, new_path, uv_resolver(resolve, reject))
  end)
end

---Like `vim.uv.fs_unlink`, but returns a promise.
---@param path string
---@return OrgPromise<true> success
function M.unlink(path)
  return Promise.new(function(resolve, reject)
    uv.fs_unlink(path, uv_resolver(resolve, reject))
  end)
end

--[[
-- Functions that have a direct libuv equivalent, but have been made more
-- convenient.
--]]

---Like `vim.uv.fs_symlink`, but with the ability to catch `EEXIST`.
---@param path string
---@param new_path string
---@param flags? {exist_ok: boolean?} if `exist_ok` is true and `new_path`
---              exists already, resolve to false. The default is to raise the
---              error `EEXIST`.
---@return OrgPromise<boolean> created true if this creates a new symlink.
function M.symlink(path, new_path, flags)
  local exist_ok = flags and flags.exist_ok or false
  return Promise.new(function(resolve, reject)
    uv.fs_symlink(path, new_path, flags, function(err, success)
      if success then
        resolve(success)
      elseif exist_ok and err and vim.startswith(err, 'EEXIST') then
        resolve(false)
      else
        reject(err)
      end
    end)
  end)
end

---Like `vim.uv.fs_mkdir`, but with more convenience options.
---* `mode`: passed directly through, the default is 0o700 (u=rwx,g=,o=).
---* `parents`: if true, missing parent directories are created recursively
---* `exist_ok`: if true and `path` points at an existing directory, resolve to
---  false. The default is to raise the error `EEXIST`.
---@param path string
---@param opts? {mode: integer?, parents: boolean?, exist_ok: boolean?}
---@return OrgPromise<boolean> created true if this creates a new directory.
function M.make_dir(path, opts)
  opts = opts or {}
  local mode = opts.mode or 448 -- 0700 -> decimal
  local parents = opts.parents or false
  local exist_ok = opts.exist_ok or true
  return Promise.new(function(resolve, reject)
    uv.fs_mkdir(path, mode, function(err)
      if not err then
        return resolve(true)
      elseif vim.startswith(err, 'EEXIST:') and exist_ok then
        if M.is_dir(path) then
          resolve(false)
        else
          error(err)
        end
        return
      elseif vim.startswith(err, 'ENOENT:') and parents then
        -- Remove trailing slashes.
        path = path:match('^(.*[^/])') or path
        local parent = vim.fs.dirname(path)
        -- Avoid infinite loop if root doesn't exist:
        -- https://debbugs.gnu.org/cgi/bugreport.cgi?bug=2309
        if parent == path then
          return reject(err)
        end
        M.make_dir(parent, { mode = mode, parents = true, exist_ok = false }):next(function()
          return M
            .make_dir(path, { mode = mode, parents = false, exist_ok = false })
            ---@diagnostic disable-next-line: redundant-parameter
            :next(resolve, reject)
        end)
      else
        return reject(err)
      end
    end)
  end)
end

--[[
-- Additional functionality that builds upon libuv.
--]]

---Like `vim.fs.dir()`, but with a few sanity improvements:
---1. errors instead of returning nil if `fs_scandir()` fails;
---2. returns an iterator instead of an iterable
---3. works around <https://github.com/luvit/luv/issues/660> by manually
---   calling `fs_stat()` if the filetype can't be fetched.
---@param path string
---@return Iter entries
function M.iterdir(path)
  local dirs = vim.fs.dir(path)
  if not dirs then
    assert(vim.uv.fs_scandir(path))
    error(('could not read path: %s'):format(path))
  end
  return vim
    .iter(dirs)
    ---@param name string
    ---@param ftype? string
    :map(function(name, ftype)
      -- On network filesystems, ftype may be nil, see
      -- <https://github.com/luvit/luv/issues/660>
      if ftype == nil then
        local stat = vim.uv.fs_stat(vim.fs.joinpath(path, name))
        ftype = stat and stat.type or 'unknown'
      end
      ---@diagnostic disable: redundant-return-value
      return name, ftype
    end)
end

---Return true if the path points at a directory.
---This simply uses `fs_stat()`, so it always resolves symlinks.
---@param path string
---@return boolean result
function M.is_dir(path)
  local stat, errmsg, err = uv.fs_stat(path)
  if not stat then
    assert(err == 'ENOENT', errmsg)
    return false
  end
  return stat.type == 'directory'
end

---Return true if the path points at a symbolic link.
---@param path string
---@return boolean is_symlink
function M.is_symlink(path)
  ---@diagnostic disable-next-line: param-type-mismatch
  local stat, errmsg, err = uv.fs_lstat(path)
  if not stat then
    assert(err == 'ENOENT', errmsg)
    return false
  end
  return stat.type == 'link'
end

---Helper function to `copy_directory` and `remove_directory`.
---Scan through the given directory and return a mapping from filetype to list
---of filenames in that directory.
---@param path string
---@return table<string, string[]> map_types_to_names_lists
local function groupdir(path)
  local res = {}
  M.iterdir(path):each(function(name, ftype)
    if not name and ftype then
      error(ftype)
    end
    local names = res[ftype] or {}
    names[1 + #names] = name
    res[ftype] = names
  end)
  return res
end

---Helper function to `copy_symlink` and `copy_stats`.
---Convert the time object returned by libuv back into seconds-since-the-epoch.
---@param time uv.fs_stat.result.time
---@return number epoch
local function to_epoch(time)
  return time.sec + time.nsec / 1e9
end

---Copy an existing symlink as a symlink.
---* `keep_times`: if true, copy access and modification timestamps as well.
---* `exist_ok`: if true, don't raise an error if `new_path` already points at
---  an object.
---If both `keep_times` and `exist_ok`, this updates the timestamps of an
---existing symbolic link.
---@param path string
---@param new_path string
---@param flags? {keep_times: boolean?, exist_ok: boolean?}
---@return OrgPromise<boolean> created true if this creates a new symlink.
function M.copy_symlink(path, new_path, flags)
  local keep_times = flags and flags.keep_times or false
  local exist_ok = flags and flags.exist_ok or false
  local target = assert(uv.fs_readlink(path))
  return M.symlink(target, new_path, { exist_ok = exist_ok, dir = M.is_dir(target), junction = true })
    :next(function(created)
      if not keep_times then
        return created
      end
      local stat = assert(uv.fs_stat(path))
      local atime = to_epoch(stat.atime)
      local mtime = to_epoch(stat.mtime)
      return Promise.new(function(resolve, reject)
        uv.fs_lutime(new_path, atime, mtime, function(err)
          if err then
            reject(err)
          else
            resolve(created)
          end
        end)
      end)
    end)
end

---Copy permission bits and (potentially) timestamps from one file to another.
---@param path string
---@param new_path string
---@param keep_times boolean if true, copy access and modification timestamps
---@return nil
local function copy_stats(path, new_path, keep_times)
  local stat = assert(uv.fs_stat(path))
  assert(uv.fs_chmod(new_path, stat.mode))
  if not keep_times then
    return
  end
  local atime = to_epoch(stat.atime)
  local mtime = to_epoch(stat.mtime)
  assert(uv.fs_utime(new_path, atime, mtime))
  if M.is_symlink(new_path) then
    assert(uv.fs_lutime(new_path, atime, mtime))
  end
end

---The meat of `copy_directory`, without `create_symlink` handling.
---@param path string
---@param new_path string
---@param opts? {parents: boolean?, create_symlink: boolean?, keep_times: boolean?}
---@return OrgPromise<true> success
local function copy_directory_impl(path, new_path, opts)
  local parents = opts and opts.parents or true
  local keep_times = opts and opts.keep_times or false
  return M.make_dir(new_path, { parents = parents, exist_ok = true })
    :next(function()
      local items = groupdir(path)

      local copy_files = Promise.map(function(name)
        return M.copy_file(
          vim.fs.joinpath(path, name),
          vim.fs.joinpath(new_path, name),
          { excl = false, ficlone = true, ficlone_force = false }
        )
      end, items.file or {}, 1)

      local copy_links = Promise.map(function(name)
        return M.copy_symlink(
          vim.fs.joinpath(path, name),
          vim.fs.joinpath(new_path, name),
          { exist_ok = true, keep_times = keep_times }
        )
      end, items.link or {}, 1)

      local copy_dirs = Promise.map(function(name)
        return M.copy_directory(vim.fs.joinpath(path, name), vim.fs.joinpath(new_path, name), opts)
      end, items.directory or {}, 1)

      return Promise.all({ copy_files, copy_links, copy_dirs })
    end)
    :next(function()
      copy_stats(path, new_path, keep_times)
      return true
    end)
end

---Copy a directory recursively.
---* `parents`: if true, create non-existing parent directories
---* `create_symlink`: if true and `path` is a symbolic link, don't copy its
---  contents, but rather create a symbolic link to the same target
---* `keep_times`: if true, adjust file modification times of `new_path` to
---  those of `path`.
---@param path string
---@param new_path string
---@param opts? {parents: boolean?, create_symlink: boolean?, keep_times: boolean?}
---@return OrgPromise<true> success
function M.copy_directory(path, new_path, opts)
  local create_symlink = opts and opts.create_symlink or false
  local path_symlink_target, errmsg, err = uv.fs_readlink(path)
  if path_symlink_target and create_symlink then
    if M.is_dir(new_path) then
      new_path = vim.fs.joinpath(new_path, vim.fs.basename(path))
    end
    -- Source directory is a symbolic link, copy only the link.
    return M.symlink(path_symlink_target, new_path, { dir = true, junction = true, exist_ok = true })
  end
  assert(err == 'EINVAL', errmsg)
  return copy_directory_impl(path, new_path, opts)
end

---Delete a directory, potentially recursively.
---* `recursive`: if true, delete all contents of `path` before deleting it.
---  The default is to only delete `path` if its an empty directory.
---@param path string
---@param opts? {recursive: boolean?}
---@return OrgPromise<true> success
function M.remove_directory(path, opts)
  ---@type OrgPromise[]|nil
  local prior_jobs
  if opts and opts.recursive then
    local dirs = {}
    local rest = {}
    M
      .iterdir(path)
      ---@param name string
      ---@param ftype? string
      :each(function(name, ftype)
        if ftype == 'directory' then
          dirs[#dirs + 1] = vim.fs.joinpath(path, name)
        else
          rest[#rest + 1] = vim.fs.joinpath(path, name)
        end
      end)
    local rm_dirs = Promise.map(function(subpath)
      return M.remove_directory(subpath, opts)
    end, dirs, 1)
    local rm_files = Promise.map(function(subpath)
      return M.unlink(subpath)
    end, rest, 1)
    prior_jobs = { rm_dirs, rm_files }
  end
  return Promise.all(prior_jobs or {}):next(function()
    return Promise.new(function(resolve, reject)
      uv.fs_rmdir(path, uv_resolver(resolve, reject))
    end)
  end)
end

--[[
-- Scary hacks 💀
--]]

---Helper function to `download_file`.
---This uses NetRW to download a file and returns the download location.
---@param url string
---@return OrgPromise<string> tmpfile
local function netrw_read(url)
  return Promise.new(function(resolve, reject)
    if not vim.g.loaded_netrwPlugin then
      return reject('Netrw plugin must be loaded in order to download urls.')
    end
    vim.schedule(function()
      local ok, err = pcall(vim.fn['netrw#NetRead'], 3, url)
      if ok then
        resolve(vim.b.netrw_tmpfile)
      else
        reject(err)
      end
    end)
  end)
end

---Download a file via NetRW.
---The file is first downloaded to a temporary location (no matter the value of
---`exist_ok`) and only then copied over to `dest`. The copy operation uses the
---`exist_ok` flag exactly like `copy_file`.
---@param url string
---@param dest string
---@param opts? {exist_ok: boolean?}
---@return OrgPromise<true> success
function M.download_file(url, dest, opts)
  opts = opts or {}
  local exist_ok = opts.exist_ok or false
  return netrw_read(url):next(function(source)
    return M.copy_file(source, dest, { excl = not exist_ok, ficlone = true, ficlone_force = false })
  end)
end

return M

local config = require('orgmode.config')
local translate_id = require('orgmode.attach.translate_id')
local fileops = require('orgmode.attach.fileops')
local fs_utils = require('orgmode.utils.fs')

---An attachment node. This is either a headline or an org file.
---
---We can attach files to any outline node; this may be a headline (`ID`/`DIR`
---property in headline's properties drawer) or an entire org file (`ID`/`DIR`
---property in the buffer properties drawer). This class abstracts the
---difference for us.
---
---@class OrgAttachNode
---@field private headline? OrgHeadline
---@field private file OrgFile
local AttachNode = {}
AttachNode.__index = AttachNode

---Constructor from headlines.
---
---@param headline OrgHeadline
---@return OrgAttachNode
function AttachNode.from_headline(headline)
  ---@type OrgAttachNode
  return setmetatable({
    headline = headline,
    file = headline.file,
  }, AttachNode)
end

---Constructor from files.
---
---@param file OrgFile
---@return OrgAttachNode
function AttachNode.from_file(file)
  ---@type OrgAttachNode
  return setmetatable({
    file = file,
  }, AttachNode)
end

---Constructor from the current cursor position.
---
---If the cursor is before any headline, this uses the entire file. Otherwise,
---it uses the closest headline above the cursor.
---
---@param file OrgFile
---@param cursor? [integer, integer] (1,0)-indexed cursor position
---@return OrgAttachNode
function AttachNode.at_cursor(file, cursor)
  local headline = file:get_closest_headline_or_nil(cursor)
  return headline and AttachNode.from_headline(headline) or AttachNode.from_file(file)
end

---@param path string
function AttachNode:_make_absolute(path)
  if not path:match('^/') then
    local base = vim.fs.dirname(self.file.filename)
    path = vim.fs.joinpath(base, path)
  end
  return vim.fs.normalize(path, { expand_env = false })
end

---@return OrgFile
function AttachNode:get_file()
  return self.file
end

---@return string filename
function AttachNode:get_filename()
  return self.file.filename
end

---@return string title
function AttachNode:get_title()
  return (self.headline or self.file):get_title()
end

---Return the starting line of the attachment node.
---
---This is zero for file nodes and the 1-based line number for headline nodes.
---This is chosen such that every attachment node in an org file has
---a different line number.
---@return integer line
function AttachNode:get_start_line()
  if self.headline then
    return self.headline:node():start() + 1
  end
  return 0
end

---Look up a property, possibly recursing into parents.
---
---If `search_parents` is nil, this uses `org_attach_use_inheritance` for the
---given property.
---
---@param property_name string property name
---@param search_parents? boolean whether to recurse to parents
---@return string|nil property
function AttachNode:get_property(property_name, search_parents)
  if search_parents == nil then
    search_parents = config:use_attach_inheritance(property_name)
  end
  if search_parents then
    return self.headline and self.headline:get_property(property_name, true) or self.file:get_property(property_name)
  end
  if self.headline then
    return self.headline:get_property(property_name, false)
  end
  return (self.file:get_property(property_name))
end

---Set a property or, if `value` is nil, remove it.
---
---@param name string property name
---@param value? string property value
---@return nil
function AttachNode:set_property(name, value)
  (self.headline or self.file):set_property(name, value)
end

---Get the node's ID property if it exists, or add it.
---
---@return string id
function AttachNode:id_get_or_create()
  return (self.headline or self.file):id_get_or_create()
end

---Return an absolute folder path based on `org_attach_id_dir` and ID.
---
---This is like `id_dir_get_or_create()`, but the ID is never added and the
---resulting path must exist in the filesystem.
---
---@return string|nil attach_dir
function AttachNode:get_existing_id_dir()
  local id = self:get_property('id')
  if not id then
    return nil
  end
  local basedir = self:_make_absolute(config.org_attach_id_dir)
  if not basedir then
    return nil
  end
  local default_basedir = self:_make_absolute('./data/')
  assert(default_basedir)
  for _, func in ipairs(config.org_attach_id_to_path_function_list) do
    local name = translate_id(func, id)
    if name then
      local candidate = vim.fs.joinpath(basedir, name)
      if fileops.is_dir(candidate) then
        return candidate
      end
      local fallback = vim.fs.joinpath(default_basedir, name)
      if fileops.is_dir(fallback) then
        return fallback
      end
    end
  end
  return nil
end

---Find the attachment directory associated with this node.
---
---The result is always an absolute path.
---
---@return string|nil attach_dir
function AttachNode:get_dir()
  local dir = self:get_property('dir')
  if dir then
    return self:_make_absolute(dir)
  end
  dir = self:get_existing_id_dir()
  if dir then
    return dir
  end
  return nil
end

---Set the attachment directory on the current node.
---
---In addition to `set_property()`, this also ensures that the path is always
---absolute.
---
---@param dir string
---@return string new_dir absolute attachment directory
---@overload fun(): nil
function AttachNode:set_dir(dir)
  if dir then
    dir = vim.fn.fnamemodify(dir, ':p')
  end
  self:set_property('DIR', dir)
  return dir and self:_make_absolute(dir)
end

---Return a folder path based on `org_attach_id_dir` and ID.
---
---Try `id_to_path` functions in `org_attach_id_to_path_function_list`
---and return the first truthy result.
---
---If the node doesn't have an ID yet, it is added.
---
---The returned path is always absolute.
---
---@return string attach_dir
function AttachNode:id_dir_get_or_create()
  local id = self:id_get_or_create()
  local basedir = self:_make_absolute(config.org_attach_id_dir)
  if basedir then
    for _, func in ipairs(config.org_attach_id_to_path_function_list) do
      local name = translate_id(func, id)
      if name then
        return vim.fs.joinpath(basedir, name)
      end
    end
  end
  error(('failed to get folder for id %s, adjust org_attach_id_to_path_function_list'):format(id))
end

---Add the `org_attach_auto_tag`, if not yet present.
function AttachNode:add_auto_tag()
  -- TODO: There is currently no way to set #+FILETAGS programmatically. Do
  -- nothing when before first heading (attaching to file) to avoid blocking
  -- error. This issue exists in the Emacs version of org-attach as well.
  -- See <https://github.com/nvim-orgmode/orgmode/issues/989>.
  if config.org_attach_auto_tag and self.headline then
    -- `add_tag()` eventually calls `vim.fn.bufnr()` inside `OrgFile`, which is
    -- disallowed inside `fast-api`. Thus, we schedule this change.
    vim.schedule(function()
      self.headline:add_tag(config.org_attach_auto_tag)
    end)
  end
end

---Remove the `org_attach_auto_tag`.
function AttachNode:remove_auto_tag()
  -- TODO: There is currently no way to set #+FILETAGS programmatically. Do
  -- nothing when before first heading (attaching to file) to avoid blocking
  -- error. This issue exists in the Emacs version of org-attach as well.
  if config.org_attach_auto_tag and self.headline then
    -- `remove_tag()` eventually calls `vim.fn.bufnr()` inside `OrgFile`, which
    -- is disallowed inside `fast-api`. Thus, we schedule this change.
    vim.schedule(function()
      self.headline:remove_tag(config.org_attach_auto_tag)
    end)
  end
end

return AttachNode

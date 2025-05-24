local AttachNode = require('orgmode.attach.node')
local Core = require('orgmode.attach.core')
local Input = require('orgmode.ui.input')
local Menu = require('orgmode.ui.menu')
local Promise = require('orgmode.utils.promise')
local config = require('orgmode.config')
local remote_resource = require('orgmode.objects.remote_resource')
local ui = require('orgmode.attach.ui')
local utils = require('orgmode.utils')

local MAX_TIMEOUT = 2 ^ 31

---@class OrgAttach
---@field private core OrgAttachCore
local Attach = {}
Attach.__index = Attach

---@param opts {files:OrgFiles, links:OrgLinks}
function Attach:new(opts)
  local data = setmetatable({ core = Core.new(opts) }, self)
  data.core.links:add_type(require('orgmode.org.links.types.attachment'):new({ attach = data }))
  return data
end

---The dispatcher for attachment commands.
---Shows a list of commands and prompts for another key to execute a command.
---@return OrgMenu
function Attach:_build_menu()
  local menu = Menu:new({
    title = 'Press key for an attach command',
    prompt = 'Press key for an attach command',
  })

  menu:add_option({
    label = 'Attach a file to this task.',
    key = 'a',
    action = function()
      return self:attach()
    end,
  })
  menu:add_option({
    label = 'Attach a file by copying it.',
    key = 'c',
    action = function()
      return self:attach_cp()
    end,
  })
  menu:add_option({
    label = 'Attach a file by moving it.',
    key = 'm',
    action = function()
      return self:attach_mv()
    end,
  })
  menu:add_option({
    label = 'Attach a file by hard-linking it',
    key = 'l',
    action = function()
      return self:attach_ln()
    end,
  })
  menu:add_option({
    label = 'Attach a file by symbolic-linking it.',
    key = 'y',
    action = function()
      return self:attach_lns()
    end,
  })
  menu:add_option({
    label = 'Attach a file by download from URL.',
    key = 'u',
    action = function()
      return self:attach_url()
    end,
  })
  menu:add_option({
    label = "Attach a buffer's contents.",
    key = 'b',
    action = function()
      return self:attach_buffer()
    end,
  })
  menu:add_option({
    label = 'Create a new attachment, as a vim buffer.',
    key = 'n',
    action = function()
      return self:attach_new()
    end,
  })
  menu:add_separator({ length = #menu.title })
  menu:add_option({
    label = 'Open an attachment externally.',
    key = 'o',
    action = function()
      return self:open()
    end,
  })
  menu:add_option({
    label = 'Open an attachment in vim.',
    key = 'O',
    action = function()
      return self:open_in_vim()
    end,
  })
  menu:add_option({
    label = 'Open the attachment directory externally.',
    key = 'f',
    action = function()
      return self:reveal()
    end,
  })
  menu:add_option({
    label = 'Open the attachment directory in vim.',
    key = 'F',
    action = function()
      return self:reveal_nvim()
    end,
  })
  menu:add_separator({ length = #menu.title })
  menu:add_option({
    label = 'Delete an attachment',
    key = 'd',
    action = function()
      return self:delete_one()
    end,
  })
  menu:add_option({
    label = 'Delete all attachments.',
    key = 'D',
    action = function()
      return self:delete_all()
    end,
  })
  menu:add_option({
    label = 'Set specific attachment directory for this task.',
    key = 's',
    action = function()
      return self:set_directory()
    end,
  })
  menu:add_option({
    label = 'Unset specific attachment directory for this task.',
    key = 'S',
    action = function()
      return self:unset_directory()
    end,
  })
  menu:add_option({
    label = 'Synchronize this task with its attachment directory.',
    key = 'z',
    action = function()
      return self:sync()
    end,
  })
  menu:add_option({ label = 'Quit', key = 'q' })
  menu:add_separator({ icon = ' ', length = 1 })

  return menu
end

---@return nil
function Attach:prompt()
  local menu = self:_build_menu()
  return menu:open()
end

---@param key string
---@return string?
function Attach:open_by_key(key)
  local menu = self:_build_menu()
  local item = menu:get_entry_by_key(key)
  if not item then
    return utils.echo_error('No attachment action with key ' .. key)
  end
  return item.action()
end

---Get the current attachment node.
---
---@return OrgAttachNode
function Attach:get_current_node()
  return self.core:get_current_node()
end

---Get attachment node in a given file at a given position.
---
---@param file OrgFile
---@param cursor [integer, integer] The (1,0)-indexed cursor position in the buffer
---@return OrgAttachNode
function Attach:get_node(file, cursor)
  return AttachNode.at_cursor(file, cursor)
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
---@param node? OrgAttachNode
---@param no_fs_check? boolean if true, return the directory even if it doesn't
---                            exist
---@return string|nil attach_dir
function Attach:get_dir(node, no_fs_check)
  node = node or self.core:get_current_node()
  return self.core:get_dir_or_nil(node, no_fs_check)
end

---Helper function to handle `org_attach_preferred_new_method()` lazily.
---
---@return fun(): OrgPromise<orgmode.attach.core.new_method>
local function get_set_dir_method()
  local method = config.org_attach_preferred_new_method
  if not method then
    error('No existing directory. DIR or ID property has to be explicitly created')
  end
  if method == 'id' or method == 'dir' then
    return function()
      return Promise.resolve(method)
    end
  end
  if method == 'ask' then
    return ui.ask_new_method
  end
  error(('invalid value for org_attach_preferred_new_method: %s'):format(method))
end

---Return existing or new directory associated with the current outline node.
---
---`org_attach_preferred_new_method` decides how to attach new directory if
---neither ID nor DIR property exist.
---
---If the attachment by some reason cannot be created an error will be raised.
---
---@param node? OrgAttachNode
---@return string
function Attach:get_dir_or_create(node)
  node = node or self.core:get_current_node()
  return self.core:get_dir_or_create(node, get_set_dir_method(), ui.ask_attach_dir_property):wait(MAX_TIMEOUT)
end

---Set the DIR node property and ask to move files there.
---
---The property defines the directory that is used for attachments
---of the entry.
---
---@param node? OrgAttachNode
---@return string | nil new_dir
function Attach:set_directory(node)
  node = node or self.core:get_current_node()
  return ui
    .ask_attach_dir_property(node:get_dir())
    ---@return string | nil
    :next(function(new_dir)
      if not new_dir then
        return nil
      end
      return self.core:set_directory(node, new_dir, {
        do_copy = function(old, new)
          return ui.yes_or_no_or_cancel_slow(('Copy attachments from "%s" to "%s"? '):format(old, new))
        end,
        do_delete = function(old)
          return ui.yes_or_no_or_cancel_slow(('Delete "%s"? '):format(old))
        end,
      })
    end)
    :wait(MAX_TIMEOUT)
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
---@param node? OrgAttachNode
---@return string | nil new_dir
function Attach:unset_directory(node)
  node = node or self.core:get_current_node()
  return self.core
    :unset_directory(node, {
      do_copy = function(old, new)
        return ui.yes_or_no_or_cancel_slow(('Copy attachments from "%s" to "%s"? '):format(old, new))
      end,
      do_delete = function(old)
        return ui.yes_or_no_or_cancel_slow(('Delete "%s"? '):format(old))
      end,
    })
    :wait(MAX_TIMEOUT)
end

---Turn the autotag on.
---
---If autotagging is disabled, this does nothing.
---
---@param node? OrgAttachNode
---@return nil
function Attach:tag(node)
  self.core:tag(node or self.core:get_current_node())
end

---Turn the autotag off.
---
---If autotagging is disabled, this does nothing.
---
---@param node? OrgAttachNode
---@return nil
function Attach:untag(node)
  self.core:untag(node or self.core:get_current_node())
end

---@class orgmode.attach.attach.Options
---@inlinedoc
---@field visit_dir? boolean if true, visit the directory subsequently using
---                          `org_attach_visit_command`
---@field method? OrgAttachMethod The method via which to attach `file`;
---                               default is taken from `org_attach_method`
---@field node? OrgAttachNode

---Move/copy/link file into attachment directory of the current outline node.
---
---@param file? string The file to attach.
---@param opts? orgmode.attach.attach.Options
---@return string|nil attachment_name
function Attach:attach(file, opts)
  local node = opts and opts.node or self.core:get_current_node()
  local visit_dir = opts and opts.visit_dir or false
  local method = opts and opts.method or config.org_attach_method
  return Promise
    .resolve(file or Input.open('File to keep as an attachment: ', '', 'file'))
    ---@param chosen_file? string
    :next(function(chosen_file)
      if not chosen_file then
        return nil
      end
      -- Remove `~` and environment variables, `vim.uv.fs_*` cannot deal with
      -- them.
      chosen_file = vim.fs.normalize(chosen_file)
      return self.core:attach(node, chosen_file, {
        attach_method = method,
        set_dir_method = get_set_dir_method(),
        new_dir = ui.ask_attach_dir_property,
      })
    end)
    :next(function(attachment_name)
      if attachment_name then
        utils.echo_info(('File %s is now an attachment'):format(attachment_name))
        if visit_dir then
          local attach_dir = self.core:get_dir(node)
          self.core:reveal_nvim(attach_dir)
        end
      end
      return attachment_name
    end)
    :wait(MAX_TIMEOUT)
end

---@class orgmode.attach.attach_url.Options
---@inlinedoc
---@field visit_dir? boolean if true, visit the directory subsequently using
---                          `org_attach_visit_command`
---@field node? OrgAttachNode

---Download a URL.
---
---@param url? string
---@param opts? orgmode.attach.attach_url.Options
---@return string|nil attachment_name
function Attach:attach_url(url, opts)
  local node = opts and opts.node or self.core:get_current_node()
  local visit_dir = opts and opts.visit_dir or false
  return Promise
    .resolve()
    :next(function()
      if not url then
        return Input.open('URL of the file to attach: ')
      end
      return remote_resource.should_fetch(url):next(function(ok)
        if not ok then
          error(("remote resource %s is unsafe, won't download"):format(url))
        end
        return url
      end)
    end)
    ---@param chosen_url? string
    :next(function(chosen_url)
      if not chosen_url then
        return nil
      end
      return self.core:attach_url(node, chosen_url, {
        set_dir_method = get_set_dir_method(),
        new_dir = ui.ask_attach_dir_property,
      })
    end)
    :next(function(attachment_name)
      if attachment_name then
        utils.echo_info(('File %s is now an attachment'):format(attachment_name))
        if visit_dir then
          local attach_dir = self.core:get_dir(node)
          self.core:reveal_nvim(attach_dir)
        end
      end
      return attachment_name
    end)
    :wait(MAX_TIMEOUT)
end

---Attach buffer's contents to current outline node.
---
---Throws a file-exists error if it would overwrite an existing filename.
---
---@param buffer? string | integer A buffer number or name.
---@param opts? orgmode.attach.attach_url.Options
---@return string|nil attachment_name
function Attach:attach_buffer(buffer, opts)
  local node = opts and opts.node or self.core:get_current_node()
  local visit_dir = opts and opts.visit_dir or false
  return Promise
    .resolve(buffer and ui.get_bufnr_verbose(buffer) or ui.select_buffer())
    ---@param bufnr? integer
    :next(function(bufnr)
      if not bufnr then
        return nil
      end
      return self.core:attach_buffer(node, bufnr, {
        set_dir_method = get_set_dir_method(),
        new_dir = ui.ask_attach_dir_property,
      })
    end)
    :next(function(attachment_name)
      if attachment_name then
        utils.echo_info(('File %s is now an attachment'):format(attachment_name))
      end
      return attachment_name
    end)
    :wait(MAX_TIMEOUT)
end

---Move/copy/link many files into attachment directory.
---
---@param files string[]
---@param opts? orgmode.attach.attach.Options
---@return string|nil attachment_name
function Attach:attach_many(files, opts)
  local node = opts and opts.node or self.core:get_current_node()
  local visit_dir = opts and opts.visit_dir or false
  local method = opts and opts.method or config.org_attach_method

  return self.core
    :attach_many(node, files, {
      set_dir_method = get_set_dir_method(),
      new_dir = ui.ask_attach_dir_property,
      attach_method = method,
    })
    :next(function(res)
      if res.successes + res.failures > 0 then
        local function plural(count)
          return count == 1 and '' or 's'
        end
        local msg = ('attached %d file%s to %s'):format(res.successes, plural(res.successes), node:get_title())
        local extra = res.failures > 0
            and { { ('failed to attach %d file%s'):format(res.failures, plural(res.failures)), 'ErrorMsg' } }
          or nil
        utils.echo_info(msg, extra)
        if res.successes > 0 and visit_dir then
          local attach_dir = self.core:get_dir(node)
          self.core:reveal_nvim(attach_dir)
        end
      end
      return nil
    end)
    :wait(MAX_TIMEOUT)
end

---@class orgmode.attach.attach_new.Options
---@inlinedoc
---@field bang? boolean if true, open the new file with `:edit!`
---@field mods? table<string,any> command modifiers to pass to `:edit[!]`; see
---                               docs for `nvim_parse_cmd()` for a list

---Create a new attachment FILE for the current outline node.
---
---The attachment is opened as a new buffer.
---
---@param name? string
---@param node? OrgAttachNode
---@param edit_opts? orgmode.attach.attach_new.Options
---@return string? attachment_name
function Attach:attach_new(name, node, edit_opts)
  node = node or self.core:get_current_node()
  return Promise
    .resolve(name or Input.open('Create attachnment named: '))
    ---@param chosen_name? string
    :next(function(chosen_name)
      if not chosen_name or chosen_name == '' then
        return nil
      end
      return self.core:attach_new(node, chosen_name, {
        set_dir_method = get_set_dir_method(),
        new_dir = ui.ask_attach_dir_property,
        edit_bang = edit_opts and edit_opts.bang or false,
        edit_mods = edit_opts and edit_opts.mods or {},
      })
    end)
    :next(function(attachment_name)
      if attachment_name then
        utils.echo_info(('new attachment %s'):format(attachment_name))
      end
      return attachment_name
    end)
    :wait(MAX_TIMEOUT)
end

---Attach a file by copying it.
---
---@param node? OrgAttachNode
---@return string|nil attachment_name
function Attach:attach_cp(node)
  return self:attach(nil, { method = 'cp', node = node })
end

---Attach a file by moving (renaming) it.
---
---@param node? OrgAttachNode
---@return string|nil attachment_name
function Attach:attach_mv(node)
  return self:attach(nil, { method = 'mv', node = node })
end

---Attach a file by creating a hard link to it.
---
---Beware that this does not work on systems that do not support hard links.
---On some systems, this apparently does copy the file instead.
---
---@param node? OrgAttachNode
---@return string|nil attachment_name
function Attach:attach_ln(node)
  return self:attach(nil, { method = 'ln', node = node })
end

---Attach a file by creating a symbolic link to it.
---
---Beware that this does not work on systems that do not support symbolic
---links. On some systems, this apparently does copy the file instead.
---
---@param node? OrgAttachNode
---@return string|nil attachment_name
function Attach:attach_lns(node)
  return self:attach(nil, { method = 'lns', node = node })
end

---Open the attachments directory via `vim.ui.open()`.
---
---@param attach_dir? string the directory to open
---@return nil
function Attach:reveal(attach_dir)
  attach_dir = attach_dir or self:get_dir_or_create()
  local res = self.core:reveal(attach_dir):wait()
  if res.code ~= 0 then
    error(('exit code %d for opening: %s'):format(res.code, attach_dir))
  end
end

---Open the attachments directory via `org_attach_visit_command`.
---
---@param attach_dir? string the directory to open
---@return nil
function Attach:reveal_nvim(attach_dir)
  attach_dir = attach_dir or self:get_dir_or_create()
  return self.core:reveal_nvim(attach_dir)
end

---Open an attached file via `vim.ui.open()`.
---
---@param name? string name of the file to open
---@param node? OrgAttachNode
---@return nil
function Attach:open(name, node)
  node = node or self.core:get_current_node()
  local attach_dir = self.core:get_dir(node)
  ---@type vim.SystemObj?
  local obj = Promise.resolve(name or ui.select_attachment('Open', attach_dir))
    :next(function(chosen_name)
      if not chosen_name then
        return
      end
      return self.core:open(chosen_name, node)
    end)
    :wait(MAX_TIMEOUT)
  if obj then
    local res = obj:wait()
    if res.code ~= 0 then
      error(('exit code %d for command: %s'):format(res.code, obj.cmd))
    end
  end
end

---Open an attached file via `:edit`.
---
---@param name? string name of the file to open
---@param node? OrgAttachNode
---@return nil
function Attach:open_in_vim(name, node)
  node = node or self.core:get_current_node()
  local attach_dir = self.core:get_dir(node)
  return Promise.resolve(name or ui.select_attachment('Open', attach_dir))
    :next(function(chosen_name)
      if not chosen_name then
        return
      end
      self.core:open_in_vim(chosen_name, node)
    end)
    :wait(MAX_TIMEOUT)
end

---Delete a single attachment.
---
---@param name? string the name of the attachment to delete
---@param node? OrgAttachNode
---@return nil
function Attach:delete_one(name, node)
  node = node or self.core:get_current_node()
  local attach_dir = self.core:get_dir(node)
  return Promise.resolve(name or ui.select_attachment('Delete', attach_dir))
    :next(function(chosen_name)
      if not chosen_name then
        return
      end
      return self.core:delete_one(node, chosen_name)
    end)
    :wait(MAX_TIMEOUT)
end

---Delete all attachments from the current outline node.
---
---This actually deletes the entire attachment directory. A safer way is to
---open the directory with `reveal` and delete from there.
---
---@param force? boolean if true, delete directory will recursively deleted with no prompts.
---@param node? OrgAttachNode
---@return nil
function Attach:delete_all(force, node)
  node = node or self.core:get_current_node()
  return Promise.resolve(force or ui.yes_or_no_or_cancel_slow('Remove all attachments? '))
    :next(function(do_delete)
      if not do_delete then
        return Promise.reject('Cancelled')
      end
      return self.core:delete_all(node, function()
        return Promise.resolve(force or ui.yes_or_no_or_cancel_slow('Recursive? '))
      end)
    end)
    :next(function()
      utils.echo_info('Attachment directory removed')
      return nil
    end)
    :wait(MAX_TIMEOUT)
end

---Maybe delete subtree attachments when archiving.
---
---This function is called via the `OrgHeadlineArchivedEvent`. The option
---`org_attach_archive_delete' controls its behavior."
---
---@param headline OrgHeadline
---@return nil
function Attach:maybe_delete_archived(headline)
  local delete = config.org_attach_archive_delete
  if delete == 'always' then
    self:delete_all(true, AttachNode.from_headline(headline))
  end
  if delete == 'ask' then
    self:delete_all(false, AttachNode.from_headline(headline))
  end
end

---Synchronize the current outline node with its attachments.
---
---Useful after files have been added/removed externally. The Option
---`org_attach_sync_delete_empty_dir` controls the behavior for empty
---attachment directories. (This ignores files whose name ends with
---a tilde `~`.)
---
---@param node? OrgAttachNode
---@return nil
function Attach:sync(node)
  node = node or self.core:get_current_node()
  local function delete_empty_dir()
    local opt = config.org_attach_sync_delete_empty_dir
    if opt == 'always' then
      return Promise.resolve(true)
    elseif opt == 'never' then
      return Promise.resolve(false)
    elseif opt == 'ask' then
      return ui.yes_or_no_or_cancel_slow('Attachment directory is empty. Delete? ')
    else
      return Promise.reject(('invalid value for org_attach_sync_delete_empty_dir: %s'):format(opt))
    end
  end
  return self.core:sync(node, delete_empty_dir):wait(MAX_TIMEOUT)
end

---Expand links in current buffer.
---
---It is meant to be added to `org_export_before_parsing_hook`."
---TODO: Add this hook. Will require refactoring `orgmode.export`.
---
---@param bufnr? integer
---@return nil
function Attach:expand_links(bufnr)
  bufnr = bufnr or 0
  local file = self.core.files:get(vim.api.nvim_buf_get_name(bufnr))
  local total = 0
  local miss = 0
  self.core
    :on_every_attachment_link(file, function(attach_dir, basename)
      total = total + 1
      if not attach_dir then
        miss = miss + 1
        return
      end
      return 'file:' .. vim.fs.joinpath(attach_dir, basename)
    end)
    :next(function()
      if miss > 0 then
        utils.echo_warning(('failed to expand %d/%d attachment links'):format(miss, total))
      else
        utils.echo_info(('expanded %d attachment links'):format(total))
      end
      return nil
    end)
    :wait(MAX_TIMEOUT)
end

return Attach

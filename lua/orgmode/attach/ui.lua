local AttachNode = require('orgmode.attach.node')
local Input = require('orgmode.ui.input')
local Promise = require('orgmode.utils.promise')
local fileops = require('orgmode.attach.fileops')
local utils = require('orgmode.utils')

local M = {}

---Yes/no dialog that forces the user to type one of the two words.
---
---This should only be used to ask questions where one option involves
---inevitable data loss.
---
---Uses `orgmode.ui.input` for user interaction, so it always returns
---a promise. The return value is `true` for yes, `false` for no and `nil` if
---the user cancels with `<Esc>`. This should back out of the operation. Don't
---use this function if there is no way to back out.
---
---@param msg string
---@return OrgPromise<boolean | nil> choice
function M.yes_or_no_or_cancel_slow(msg)
  local function ask()
    return Input.open(msg .. '(yes or no, ESC to cancel) '):next(function(answer)
      answer = answer:lower()
      if answer == 'yes' then
        return true
      elseif answer == 'no' then
        return false
      else
        return ask()
      end
    end)
  end
  return ask()
end

---Ask the user for a new DIR property on a node.
---
---Errors if the user cancels.
---
---@param prev_dir string | nil
---@return OrgPromise<string | nil>
function M.ask_attach_dir_property(prev_dir)
  return Input.open('Attachment directory: ', prev_dir or '', 'dir')
end

---Ask the user which way to create an attachment directory.
---
---Used to implement `org_attach_preferred_new_method=='ask'`.
---
---@return OrgPromise<'id'|'dir'|nil> method
function M.ask_new_method()
  -- Can't use OrgMenu here because it doesn't allow us to catch ESC.
  return Promise.new(function(resolve, reject)
    vim.ui.select({ 'id', 'dir' }, {
      prompt = 'How to create attachments directory?',
      format_item = function(item)
        return ('Create new %s property'):format(item:upper())
      end,
    }, function(item)
      if item then
        resolve(item)
      else
        reject('Input canceled')
      end
    end)
  end)
end

---Dialog that has user select one among a given number of attachment nodes.
---
---Returns nil if the user cancels with `<Esc>`.
---
---Errors if the user's selection doesn't match a single node.
---
---@param nodes OrgAttachNode[]
---@return OrgPromise<OrgAttachNode | nil> selection
function M.select_node(nodes)
  ---@param arglead string
  ---@return OrgAttachNode[]
  local function get_matches(arglead)
    return vim.fn.matchfuzzy(nodes, arglead, { matchseq = true, text_cb = AttachNode.get_title })
  end
  return Input.open('Select an attachment node: ', '', get_matches):next(function(choice)
    if not choice then
      return nil
    end
    local matches = get_matches(choice)
    if #matches == 1 then
      return matches[1]
    end
    if #matches > 1 then
      error('more than one match for ' .. tostring(choice))
    else
      error('no matching buffer for ' .. tostring(choice))
    end
  end)
end

---Helper for `make_completion()`.
---
---@param directory string
---@param show_hidden? boolean
---@return string[] file_names
local function list_files(directory, show_hidden)
  ---@param path string
  ---@return string ftype
  local function resolve_links(path)
    local target = vim.uv.fs_realpath(path)
    local stat = target and vim.uv.fs_stat(target)
    return stat and stat.type or 'file'
  end
  local filter = show_hidden and function()
    return true
  end or function(name)
    return not vim.startswith(name, '.') and not vim.endswith(name, '~')
  end
  local dirs = {}
  local files = {}
  fileops
    .iterdir(directory)
    :filter(filter)
    :map(
      ---@param name string
      ---@param ftype string
      ---@return string name
      ---@return string ftype
      function(name, ftype)
        if ftype == 'link' then
          ftype = resolve_links(vim.fs.joinpath(directory, name))
        end
        ---@diagnostic disable-next-line: redundant-return-value
        return name, ftype
      end
    )
    ---@param name string
    ---@param ftype string
    :each(function(name, ftype)
      if ftype == 'directory' then
        dirs[#dirs + 1] = name .. '/'
      else
        files[#files + 1] = name
      end
    end)
  -- Ensure that directories are sorted before files.
  table.sort(dirs)
  table.sort(files)
  return vim.list_extend(dirs, files)
end

---Return a completion function for attachments.
---
---@param root string the attachment directory
---@return fun(arglead: string): string[]
local function make_completion(root)
  ---@param arglead string
  ---@return string[]
  return function(arglead)
    local dirname = vim.fs.dirname(arglead)
    local searchdir = vim.fs.normalize(vim.fs.joinpath(root, dirname))
    local basename = vim.fs.basename(arglead)
    local show_hidden = vim.startswith(basename, '.')
    local candidates = list_files(searchdir, show_hidden)
    -- Only call matchfuzzy() if it won't break.
    if basename ~= '' and basename:len() <= 256 then
      candidates = vim.fn.matchfuzzy(candidates, basename)
    end
    -- Don't prefix `./` to the paths.
    if dirname ~= '.' then
      candidates = vim.tbl_map(function(name)
        return vim.fs.joinpath(dirname, name)
      end, candidates)
    end
    return candidates
  end
end

---Dialog that has user select an existing attachment file.
---
---Returns nil if the user cancels with `<Esc>`.
---
---@param action string
---@param attach_dir string
---@return OrgPromise<string> attach_file
function M.select_attachment(action, attach_dir)
  return Input.open(action .. ' attachment: ', '', make_completion(attach_dir))
end

---Like `vim.fn.bufnr()`, but error instead of returning `-1`.
---
---@param buf integer | string
---@return integer bufnr
function M.get_bufnr_verbose(buf)
  local bufnr = vim.fn.bufnr(buf)
  if bufnr ~= -1 then
    return bufnr
  end
  -- bufnr() failed, was there no match or more than one?
  if type(buf) ~= 'string' then
    error(('buffer %d does not exist'):format(buf))
  end
  local matches = vim.fn.getcompletion(buf, 'buffer')
  if #matches > 1 then
    error('more than one match for ' .. tostring(buf))
  end
  if #matches == 1 then
    -- Surprise match?!
    bufnr = vim.fn.bufnr(matches[1])
    if bufnr > 0 then
      return bufnr
    end
  end
  error('no matching buffer for ' .. tostring(buf))
end

---Simple buffer selection dialog.
---
---Returns nil if the user backs out.
---
---Errors if the user's choice is ambiguous.
---
---@return OrgPromise<integer | nil> bufnr
function M.select_buffer()
  return Input.open('Select a buffer: ', '', 'buffer'):next(function(bufname)
    if not bufname then
      return nil
    elseif bufname == '' then
      utils.echo_error('Input canceled')
      return nil
    end
    return M.get_bufnr_verbose(bufname)
  end)
end

return M

local Input = require('orgmode.ui.input')
local Promise = require('orgmode.utils.promise')
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

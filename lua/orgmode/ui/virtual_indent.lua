---@class VirtualIndent
---@field private _ns_id number extmarks namespace id
local VirtualIndent = {
  enabled = false,
  lib = {},
}

function VirtualIndent:new()
  if self.enabled then
    return self
  end
  self._ns_id = vim.api.nvim_create_namespace('orgmode.ui.indent')
  self.lib.headline = require('orgmode.treesitter.headline')
  self.enabled = true
  return self
end

function VirtualIndent:_delete_old_extmarks(buffer, start_line, end_line)
  local old_extmarks = vim.api.nvim_buf_get_extmarks(
    buffer,
    self._ns_id,
    { start_line, 0 },
    { end_line, 0 },
    { type = 'virt_text' }
  )
  for _, ext in ipairs(old_extmarks) do
    vim.api.nvim_buf_del_extmark(buffer, self._ns_id, ext[1])
  end
end

function VirtualIndent:_get_indent_size(line)
  local headline = self.lib.headline.from_cursor({ line + 1, 1 })

  if headline then
    local headline_line, _, _ = headline.headline:start()

    if headline_line ~= line then
      return headline:level() + 1
    end
  end

  return 0
end

---@param bufnr number buffer id
---@param start_line number start line number to set the indentation, 0-based inclusive
---@param end_line number end line number to set the indentation, 0-based inclusive
---@param ignore_ts? boolean whether or not to skip the treesitter start & end lookup
function VirtualIndent:set_indent(bufnr, start_line, end_line, ignore_ts)
  ignore_ts = ignore_ts or false
  local headline = self.lib.headline.from_cursor({ start_line + 1, 1 })
  if headline and not ignore_ts then
    local parent = headline.headline:parent()
    start_line = parent:start()
    end_line = parent:end_()
  end
  if start_line > 0 then
    start_line = start_line - 1
  end
  self:_delete_old_extmarks(bufnr, start_line, end_line)
  for line = start_line, end_line do
    local indent = self:_get_indent_size(line)

    if indent > 0 then
      -- NOTE: `ephemeral = true` is not implemented for `inline` virt_text_pos :(
      vim.api.nvim_buf_set_extmark(bufnr, self._ns_id, line, 0, {
        virt_text = { { string.rep(' ', indent), 'OrgIndent' } },
        virt_text_pos = 'inline',
        right_gravity = false,
      })
    end
  end
end

---@param bufnr? number buffer id
function VirtualIndent:attach(bufnr)
  bufnr = bufnr or 0
  self:set_indent(0, 0, vim.api.nvim_buf_line_count(bufnr) - 1, true)

  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, _, _, start_line, _, end_line)
      -- HACK: By calling `set_indent` twice, once synchronously and once in `vim.schedule` we get smooth usage of the
      -- virtual indent in most cases and still properly handle undo redo. Unfortunately this is called *early* when
      -- `undo` or `redo` is used causing the padding to be incorrect for some headlines.
      self:set_indent(bufnr, start_line, end_line)
      vim.schedule(function()
        self:set_indent(bufnr, start_line, end_line)
      end)
    end,
  })
end

return VirtualIndent

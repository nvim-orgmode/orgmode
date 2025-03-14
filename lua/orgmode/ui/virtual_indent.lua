local tree_utils = require('orgmode.utils.treesitter')
---@class OrgVirtualIndent
---@field private _ns_id number extmarks namespace id
---@field private _bufnr integer Buffer VirtualIndent is attached to
---@field private _attached boolean Whether or not VirtualIndent is attached for its buffer
---@field private _bufnrs table<integer, OrgVirtualIndent> Buffers with VirtualIndent attached
local VirtualIndent = {
  _ns_id = vim.api.nvim_create_namespace('orgmode.ui.indent'),
  _bufnrs = {},
}
VirtualIndent.__index = VirtualIndent

--- Creates a new instance of VirtualIndent for a given buffer or returns the existing instance if
--- one exists
---@param bufnr? integer Buffer to use for VirtualIndent when attached
---@return OrgVirtualIndent
function VirtualIndent:new(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if self._bufnrs[bufnr] then
    return self._bufnrs[bufnr]
  end
  local this = setmetatable({
    _bufnr = bufnr,
    _attached = false,
  }, self)
  self._bufnrs[bufnr] = this
  return this
end

function VirtualIndent.toggle_buffer_indent_mode(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local instance = VirtualIndent:new(bufnr)
  local message = ''
  if vim.b[bufnr].org_indent_mode then
    message = 'disabled'
    instance:detach()
  else
    message = 'enabled'
    instance:attach()
  end
  require('orgmode.utils').echo_info('Org-Indent mode ' .. message .. ' in current buffer')
end

function VirtualIndent:_delete_old_extmarks(start_line, end_line)
  local ok, old_extmarks = pcall(
    vim.api.nvim_buf_get_extmarks,
    self._bufnr,
    self._ns_id,
    { start_line, 0 },
    { end_line, 0 },
    { type = 'virt_text' }
  )
  if not ok then
    old_extmarks = {}
  end
  for _, ext in ipairs(old_extmarks) do
    vim.api.nvim_buf_del_extmark(self._bufnr, self._ns_id, ext[1])
  end
end

function VirtualIndent:_get_indent_size(line, tree_has_errors)
  -- If tree has errors, we can't rely on treesitter to get the correct indentation
  -- Fallback to searching closest headline by checking each previous line
  if tree_has_errors then
    local linenr = line
    while linenr > 0 do
      -- We offset `linenr` by 1 because it's 0-indexed and `getline` is 1-indexed
      local _, level = vim.fn.getline(linenr + 1):find('^%*+')
      if level then
        -- If the current line is a headline we should return no virtual indentation, otherwise
        -- return virtual indentation
        return (linenr == line and 0 or level + 1)
      end
      linenr = linenr - 1
    end
  end

  local headline = tree_utils.closest_headline_node({ line + 1, 1 })

  if headline then
    local headline_line = headline:start()

    if headline_line ~= line then
      local _, level = headline:field('stars')[1]:end_()
      return level + 1
    end
  end

  return 0
end

---@param start_line number start line number to set the indentation, 0-based inclusive
---@param end_line number end line number to set the indentation, 0-based inclusive
---@param ignore_ts? boolean whether or not to skip the treesitter start & end lookup
function VirtualIndent:set_indent(start_line, end_line, ignore_ts)
  ignore_ts = ignore_ts or false
  local headline = tree_utils.closest_headline_node({ start_line + 1, 1 })
  if headline and not ignore_ts then
    local parent = headline:parent()
    if parent then
      start_line = math.min(parent:start(), start_line)
      end_line = math.max(parent:end_(), end_line)
    end
  end
  if start_line > 0 then
    start_line = start_line - 1
  end

  local node_at_cursor = tree_utils.get_node()
  local tree_has_errors = false
  if node_at_cursor then
    tree_has_errors = node_at_cursor:tree():root():has_error()
  end

  self:_delete_old_extmarks(start_line, end_line)
  for line = start_line, end_line do
    local indent = self:_get_indent_size(line, tree_has_errors)

    if indent > 0 then
      -- NOTE: `ephemeral = true` is not implemented for `inline` virt_text_pos :(
      pcall(vim.api.nvim_buf_set_extmark, self._bufnr, self._ns_id, line, 0, {
        virt_text = { { string.rep(' ', indent), 'OrgIndent' } },
        virt_text_pos = 'inline',
        right_gravity = false,
        priority = 110,
      })
    end
  end
end

--- Enables virtual indentation in registered buffer
function VirtualIndent:attach()
  if self._attached then
    return
  end
  self:set_indent(0, vim.api.nvim_buf_line_count(self._bufnr) - 1, true)

  vim.api.nvim_buf_attach(self._bufnr, false, {
    on_lines = function(_, _, _, start_line, _, end_line)
      if not self._attached then
        return true
      end

      vim.schedule(function()
        self:set_indent(start_line, end_line)
      end)
    end,
    on_reload = function()
      self:set_indent(0, vim.api.nvim_buf_line_count(self._bufnr) - 1, true)
    end,
    on_detach = function(_, bufnr)
      self:detach()
      self._bufnrs[bufnr] = nil
    end,
  })
  self._attached = true
  vim.b[self._bufnr].org_indent_mode = true
end

function VirtualIndent:detach()
  if not self._attached then
    return
  end
  self:_delete_old_extmarks(0, vim.api.nvim_buf_line_count(self._bufnr) - 1)
  self._attached = false
  vim.b[self._bufnr].org_indent_mode = false
end

return VirtualIndent

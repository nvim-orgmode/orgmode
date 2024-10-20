local config = require('orgmode.config')
local ts_utils = require('orgmode.utils.treesitter')
local utils = require('orgmode.utils')
local org = require('orgmode')

---@class OrgEditSpecial
---@field files OrgFiles
local EditSpecial = {
  context_var = '__org_edit_special_ctx',
  aborted_var = '__org_edit_special_aborted',
  block_types = {
    SRC = require('orgmode.objects.edit_special.types.src'),
    src = require('orgmode.objects.edit_special.types.src'),
  },
}

---@return OrgEditSpecial
function EditSpecial:new()
  local o = {}

  setmetatable(o, self)
  self.__index = self

  return o
end

function EditSpecial:_parse_position()
  local nearest_block_node_info = self:_get_nearest_block_node()

  if not nearest_block_node_info then
    utils.echo_warning('No block node found near cursor')
    self.block_type = nil

    return
  end

  self.block_type = nearest_block_node_info.children.name.text:upper()

  if not self.block_types[self.block_type] then
    utils.echo_warning(string.format([[Edit special for block of type '%s' is not supported]], self.block_type))

    return
  end

  return nearest_block_node_info
end

function EditSpecial:_set_context(bufnr, ctx)
  vim.api.nvim_buf_set_var(bufnr, self.context_var, ctx)
end

function EditSpecial:get_context(bufnr)
  local exists, ctx = pcall(vim.api.nvim_buf_get_var, bufnr or self.org_bufnr, self.context_var)
  ---@cast ctx table
  if not exists then
    error({ message = 'Unable to find context for edit special action' })
  end

  if not vim.api.nvim_buf_is_valid(ctx.org_bufnr) then
    error({ message = 'Org buffer associated with edit special no longer valid' })
  end

  ctx.file = org.files:get(ctx.filename)
  if not ctx.file then
    error({ message = 'Edit special callback with invalid file: ' .. (ctx.filename or '?') })
  end

  ctx.start_extmark_pos = vim.api.nvim_buf_get_extmark_by_id(ctx.org_bufnr, ctx.extmark_ns, ctx.start_extmark, {})
  ctx.end_extmark_pos = vim.api.nvim_buf_get_extmark_by_id(ctx.org_bufnr, ctx.extmark_ns, ctx.end_extmark, {})

  return ctx
end

function EditSpecial:init_in_org_buffer()
  self.org_bufnr = vim.api.nvim_get_current_buf()
  self.org_pos = vim.api.nvim_win_get_cursor(0)
  self.file = org.files:get_current_file()
end

function EditSpecial:init()
  local position_info = self:_parse_position()
  if not position_info then
    return
  end

  local bufnr, ctx = self.block_types[self.block_type]
    :new({
      file = self.file,
      org_bufnr = self.org_bufnr,
      org_pos = self.org_pos,
      position_info = position_info,
    })
    :init()

  self:_set_context(bufnr, ctx)

  config:setup_mappings('edit_src', bufnr)

  local edit_special_augroup = vim.api.nvim_create_augroup('org_edit_special', { clear = true })
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = bufnr,
    group = edit_special_augroup,
    callback = function()
      require('orgmode').action('org_mappings._edit_special_callback')
    end,
    once = true,
  })
end

function EditSpecial:write()
  local ctx = self:get_context(vim.api.nvim_get_current_buf())

  self.block_types[ctx.block_type]
    :new({
      org_bufnr = ctx.org_bufnr,
      org_pos = ctx.org_pos,
      file = ctx.file,
    })
    :write(ctx)
end

function EditSpecial:done()
  local wiped_bufnr = vim.api.nvim_get_current_buf()
  local ctx = self:get_context(wiped_bufnr)

  vim.api.nvim_buf_del_extmark(ctx.org_bufnr, ctx.extmark_ns, ctx.start_extmark)
  vim.api.nvim_buf_del_extmark(ctx.org_bufnr, ctx.extmark_ns, ctx.end_extmark)

  local block = self.block_types[ctx.block_type]:new({
    org_bufnr = ctx.org_bufnr,
    org_pos = ctx.org_pos,
    file = ctx.file,
  })

  local ok, aborted = pcall(vim.api.nvim_buf_get_var, ctx.bufnr, self.aborted_var)
  if ok and aborted then
    block:abort()
    utils.echo_info('Aborting SRC block edits')

    return
  end

  block:write(ctx)

  vim.schedule(function()
    local winid = vim.fn.bufwinid(ctx.org_bufnr) or -1
    if winid == -1 then
      return
    end

    if vim.api.nvim_win_get_tabpage(winid) == vim.api.nvim_get_current_tabpage() then
      vim.api.nvim_set_current_win(winid)
    end
  end)
end

function EditSpecial:_get_nearest_block_node()
  local current_node = self.file:get_node_at_cursor(self.org_pos)
  if not current_node then
    return
  end
  local block_node = ts_utils.parents_until(current_node, 'block')
  if not block_node then
    return
  end

  -- Block might not have contents yet, which is fine
  local children_nodes = self.file:get_ts_matches(
    '(block name: (expr) @name parameter: (expr) @parameters contents: (contents)? @contents)',
    block_node
  )[1]
  if not children_nodes or not children_nodes.name or not children_nodes.parameters then
    return
  end

  return {
    node = block_node,
    children = children_nodes,
  }
end

EditSpecial.abort = function()
  vim.b[EditSpecial.aborted_var] = true
  vim.cmd([[q!]])
end

return EditSpecial

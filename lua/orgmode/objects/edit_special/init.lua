local Files = require('orgmode.parser.files')
local Help = require('orgmode.objects.help')
local config = require('orgmode.config')
local utils = require('orgmode.utils')

local EditSpecial = {
  context_var = '__org_edit_special_ctx',
  aborted_var = '__org_edit_special_aborted',
  block_types = {
    SRC = require('orgmode.objects.edit_special.types.src'),
  },
}

function EditSpecial:new()
  local o = {}

  setmetatable(o, self)
  self.__index = self

  return o
end

function EditSpecial:_parse_position()
  local nearest_block_node_info = utils.get_nearest_block_node(self.file, self.org_pos, true)

  if not nearest_block_node_info then
    utils.echo_warning('No block node found near cursor')
    self.block_type = nil

    return
  end

  self.block_type = nearest_block_node_info.children.name.text:upper()

  if not self.block_types[self.block_type] then
    utils.echo_warning(string.format([[Edit special for block of type '%s' is not supported]]))

    return
  end

  return nearest_block_node_info
end

function EditSpecial:_set_context(bufnr, ctx)
  vim.api.nvim_buf_set_var(bufnr, self.context_var, ctx)
end

function EditSpecial:get_context(bufnr)
  local exists, ctx = pcall(vim.api.nvim_buf_get_var, bufnr or self.org_bufnr, self.context_var)
  if not exists then
    error({ message = 'Unable to find context for edit special action' })
  end

  if not vim.api.nvim_buf_is_valid(ctx.org_bufnr) then
    error({ message = 'Org buffer associated with edit special no longer valid' })
  end

  ctx.file = Files.get(ctx.filename)
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
  self.file = Files.get_current_file()
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

  utils.buf_keymap(
    bufnr,
    'n',
    config.mappings.edit_src.org_edit_src_abort,
    string.format([[<Cmd>let b:%s = v:true | q!<CR>]], self.aborted_var)
  )
  utils.buf_keymap(
    bufnr,
    'n',
    config.mappings.edit_src.org_edit_src_save,
    [[<Cmd>lua require('orgmode.objects.edit_special'):new():write()<CR>]]
  )
  utils.buf_keymap(
    bufnr,
    'n',
    config.mappings.edit_src.org_edit_src_show_help,
    [[<Cmd>lua require('orgmode.objects.help').show({ type = 'edit_src' })<CR>]]
  )

  vim.cmd([[autocmd BufWipeout <buffer> ++once lua require('orgmode').action('org_mappings._edit_special_callback')]])
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
    local winid = vim.fn.bufwinid(ctx.org_bufnr)
    if winid == -1 then
      return
    end

    if vim.api.nvim_win_get_tabpage(winid) == vim.api.nvim_get_current_tabpage() then
      vim.api.nvim_set_current_win(winid)
    end
  end)
end

EditSpecial.show_help = function()
  Help.show_help()
end

return EditSpecial

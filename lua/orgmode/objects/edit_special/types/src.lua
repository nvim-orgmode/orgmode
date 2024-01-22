local config = require('orgmode.config')
local es_utils = require('orgmode.objects.edit_special.utils')
local utils = require('orgmode.utils')

local EditSpecialSrc = {
  extmark_ns = vim.api.nvim_create_namespace('org_edit_special_extmark'),
  hl_ns = vim.api.nvim_create_namespace('org_edit_special_hl'),
}

function EditSpecialSrc:new(opts)
  local o = {}

  o.org_bufnr = opts.org_bufnr
  o.org_pos = opts.org_pos
  o.file = opts.file
  o.src_block = opts.position_info

  setmetatable(o, self)
  self.__index = self

  return o
end

function EditSpecialSrc:_update_content(action, block_start_line, content)
  local block_indent = string.rep(vim.opt.expandtab:get() and ' ' or '\t', config.org_edit_src_content_indentation)

  -- Treesitter doesn't seem to report leading tabs correctly (for example, text offset by a tab character
  -- will have its column reported as 0)
  --
  -- Grab the line itself in order to circumvent this
  local block_start_line_text =
    vim.api.nvim_buf_get_lines(self.org_bufnr, block_start_line, block_start_line + 1, false)[1]

  -- Not quite what Emacs does, but assume that the leading space of the entire block is consistent
  -- and strip that off
  local whitespace_re = '^[\t%s]+'
  local block_leading_whitespace = string.match(block_start_line_text, whitespace_re) or ''

  if action == 'remove' then
    return vim.tbl_map(function(line)
      local new_line = string.gsub(line, '^' .. block_leading_whitespace, '')
      if #new_line < #line then
        new_line = string.gsub(new_line, '^' .. block_indent, '')
      end
      return new_line
    end, content)
  elseif action == 'add' then
    return vim.tbl_map(function(line)
      return line == '' and line or (block_leading_whitespace .. block_indent .. line)
    end, content)
  end
end

function EditSpecialSrc:clear_highlights()
  vim.api.nvim_buf_clear_namespace(self.org_bufnr, self.hl_ns, 0, -1)
end

function EditSpecialSrc:_highlight_contents(range)
  self:clear_highlights()
  local start_row, start_col, end_row, end_col = unpack(range)
  vim.highlight.range(self.org_bufnr, self.hl_ns, 'OrgEditSrcHighlight', { start_row, start_col }, { end_row, end_col })
end

function EditSpecialSrc:abort()
  self:clear_highlights()
end

function EditSpecialSrc:init()
  local block_start_line, block_start_col, block_end_line, block_end_col = self.src_block.node:range()
  local start_extmark = vim.api.nvim_buf_set_extmark(0, self.extmark_ns, block_start_line, block_start_col, {})
  local end_extmark = vim.api.nvim_buf_set_extmark(0, self.extmark_ns, block_end_line, block_end_col, {})

  -- Only the "content" of the block should change, however we might not have content yet
  -- so base the range off of the name of the block
  local ft = self.src_block.children.parameters.text

  local bufnr = es_utils.make_temp_buf()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    utils.echo_info('Cancel editing source block, invalid buffer')
    return
  end

  vim.cmd('e ' .. vim.fn.tempname())

  local ctx = {
    block_type = 'SRC',
    bufnr = bufnr,
    end_extmark = end_extmark,
    extmark_ns = self.extmark_ns,
    filename = self.file.filename,
    org_bufnr = self.org_bufnr,
    start_extmark = start_extmark,
  }

  -- The node content 'text_list' does not include the leading whitespace of the first line of the content,
  -- grab the entire line instead
  local content = {}
  if self.src_block.children.contents then
    local content_start_line, _, content_end_line = self.src_block.children.contents.node:range()
    content = vim.api.nvim_buf_get_lines(self.org_bufnr, content_start_line, content_end_line, false)
  end

  content = self:_update_content('remove', block_start_line, content)

  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', ft, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
  vim.api.nvim_set_option_value('modified', false, { buf = ctx.bufnr })

  self:_highlight_contents({
    block_start_line + 1,
    block_start_col,
    block_end_line - 1,
    block_end_col,
  })

  return bufnr, ctx
end

function EditSpecialSrc:write(ctx)
  local content_start = ctx.start_extmark_pos[1] + 1
  local content_end = ctx.end_extmark_pos[1] - 1

  if content_start > content_end then
    -- Handle empty blocks having content written into them
    content_end = content_start
  end

  local new_content = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
  new_content = self:_update_content('add', ctx.start_extmark_pos[1], new_content)

  vim.api.nvim_buf_set_lines(ctx.org_bufnr, content_start, content_end, false, new_content)

  self.file:reload()

  -- If this is after the special buffer has been closed, our extmarks will have already
  -- been removed
  local new_start_extmark = vim.api.nvim_buf_get_extmark_by_id(ctx.org_bufnr, ctx.extmark_ns, ctx.start_extmark, {})
  local new_end_extmark = vim.api.nvim_buf_get_extmark_by_id(ctx.org_bufnr, ctx.extmark_ns, ctx.end_extmark, {})
  if #new_start_extmark > 0 and #new_end_extmark > 0 then
    self:_highlight_contents({
      new_start_extmark[1] + 1,
      new_start_extmark[2],
      new_end_extmark[1] - 1,
      new_end_extmark[2],
    })
  end
end

return EditSpecialSrc

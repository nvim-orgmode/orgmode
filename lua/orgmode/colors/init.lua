local colors = require('orgmode.colors.colors')
local namespace = vim.api.nvim_create_namespace('org_agenda')
local M = {}

---@param hex_color string hex color (#FFFFFFF)
---@return OrgColor
function M.from_hex(hex_color)
  return colors.new(hex_color)
end

---@param hlgroup string
---@return string
function M.parse_hl_fg_color(hlgroup)
  local bg = colors.validate(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(hlgroup)), 'bg', 'gui'))
  local fg = colors.validate(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(hlgroup)), 'fg', 'gui'))
  local normal_bg = colors.validate(vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID('Normal')), 'bg', 'gui'))
  local reverse = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(hlgroup)), 'reverse', 'gui')
  -- If only one color defined return that one
  if not bg and fg then
    return fg
  end
  if not fg and bg then
    return bg
  end

  if reverse == '' and bg ~= normal_bg then
    return bg
  end
  return fg
end

M.get_todo_keywords_colors = function()
  local error = M.parse_hl_fg_color('Error')
  local warning = M.parse_hl_fg_color('WarningMsg')
  local ok = M.parse_hl_fg_color('diffAdded')
  if not ok then
    ok = M.parse_hl_fg_color('DiffAdd')
  end
  if not error then
    error = M.parse_hl_fg_color('ErrorMsg')
  end

  if not ok then
    ok = '#00FF00'
  end

  if not warning then
    warning = '#FF8C00'
  end

  if not error then
    error = '#FF0000'
  end

  return {
    TODO = { gui = error, cterm = 1 },
    DONE = { gui = ok, cterm = 2 },
    deadline = {
      gui = M.from_hex(error):lighten_by(0.1):to_rgb(),
      cterm = 9,
    },
    ok = {
      gui = M.from_hex(ok):lighten_by(0.1):to_rgb(),
      cterm = 10,
    },
    warning = {
      gui = M.from_hex(warning):lighten_by(0.1):to_rgb(),
      cterm = 11,
    },
  }
end

---@class OrgHighlightEntry
---@field range OrgRange
---@field hlgroup string
---@field namespace? number
---@field spell? boolean
---@field priority? number
---@field conceal? boolean
---@field url? string
---@field whole_line? boolean

---@param highlights OrgHighlightEntry[]
---@param clear? boolean
---@return string
M.apply_highlights = function(highlights, clear, bufnr)
  bufnr = bufnr or 0
  if clear then
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end
  for _, hl in ipairs(highlights) do
    M.highlight(hl, bufnr)
  end
end

---@param hl OrgHighlightEntry
M.highlight = function(hl, bufnr)
  bufnr = bufnr or 0
  local start_row = hl.range.start_line - 1
  local start_col = hl.range.start_col - 1
  local opts = {
    hl_group = hl.hlgroup,
    end_row = hl.range.end_line - 1,
    end_col = hl.range.end_col - 1,
    spell = hl.spell,
    priority = hl.priority,
    conceal = hl.conceal,
    url = hl.url,
  }

  if hl.whole_line then
    opts.end_row = start_row + 1
    opts.end_col = 0
    opts.hl_eol = true
  end

  if opts.end_col < 0 then
    opts.end_col = 99999
    opts.strict = false
  end

  return vim.api.nvim_buf_set_extmark(bufnr, hl.namespace or namespace, start_row, start_col, opts)
end

---@param virt_texts{ range: OrgRange, content: string, virt_text_pos: string, hl_groups: string[] }[]
---@param bufnr number
M.virtual_text = function(virt_texts, bufnr)
  bufnr = bufnr or 0
  for _, virt_text in ipairs(virt_texts) do
    local start_line = virt_text.range.start_line - 1
    vim.api.nvim_buf_set_extmark(bufnr, namespace, start_line, 0, {
      virt_text = { { virt_text.content, virt_text.hl_groups } },
      virt_text_pos = virt_text.virt_text_pos,
      hl_mode = 'combine',
    })
  end
end

---@param bufnr number
---@param start_line? number Default: 0
---@param end_line? number Default: -1
M.clear_extmarks = function(bufnr, start_line, end_line)
  local extmarks = vim.api.nvim_buf_get_extmarks(
    bufnr,
    namespace,
    { start_line, 0 },
    { end_line, 99999 },
    { details = true }
  )
  for _, extmark in ipairs(extmarks) do
    vim.api.nvim_buf_del_extmark(bufnr, namespace, extmark[1])
  end
end

M.add_hr = function(bufnr, line, separator)
  vim.api.nvim_buf_set_lines(bufnr, line, line, false, { '' })
  local width = vim.api.nvim_win_get_width(0)
  vim.api.nvim_buf_set_extmark(bufnr, namespace, line, 0, {
    virt_text = { { string.rep(separator, width), '@org.agenda.separator' } },
    virt_text_pos = 'overlay',
  })
end

return M

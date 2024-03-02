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

---@param highlights table[]
---@param clear? boolean
---@return string
M.highlight = function(highlights, clear, bufnr)
  bufnr = bufnr or 0
  if clear then
    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  end
  for _, hl in ipairs(highlights) do
    if hl.whole_line then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, hl.range.start_line - 1, hl.range.start_col - 1, {
        hl_group = hl.hlgroup,
        end_line = hl.range.start_line,
        hl_eol = true,
      })
    else
      vim.api.nvim_buf_add_highlight(
        bufnr,
        namespace,
        hl.hlgroup,
        hl.range.start_line - 1,
        hl.range.start_col - 1,
        hl.range.end_col - 1
      )
    end
  end
end

return M

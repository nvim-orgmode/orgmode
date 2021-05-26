local colors = require('orgmode.colors.colors')
local M = {}

---@param hex_color string hex color (#FFFFFFF)
---@return Color
function M.from_hex(hex_color)
   return colors.new(hex_color)
end

---@param hlgroup string
---@return string
function M.parse_hl_fg_color(hlgroup)
   local bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(hlgroup)), 'bg', 'gui')
   local fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(hlgroup)), 'fg', 'gui')
   local reverse = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(hlgroup)), 'reverse', 'gui')
   -- If only one color defined return that one
   if bg == '' and fg ~= '' then return fg end
   if fg == '' and bg ~= '' then return bg end

   if reverse == '' then
      return bg
   end
   return fg
end

M.get_todo_keywords_colors = function()
   local error = M.parse_hl_fg_color('ErrorMsg')
   local warning = M.parse_hl_fg_color('WarningMsg')
   local ok = M.parse_hl_fg_color('diffAdded')
   if ok == '' then
      ok = M.parse_hl_fg_color('DiffAdd')
   end

   return {
      TODO = error,
      DONE = ok,
      deadline = M.from_hex(error):lighten_by(0.1):to_rgb(),
      ok = M.from_hex(ok):lighten_by(0.1):to_rgb(),
      warning = M.from_hex(warning):lighten_by(0.1):to_rgb(),
   }
end

---@param highlights table[]
---@return string
M.highlight = function(highlights)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(0, 0, hl.hlgroup, hl.range.start_line - 1, hl.range.start_col - 1, hl.range.end_col - 1)
  end
end

return M

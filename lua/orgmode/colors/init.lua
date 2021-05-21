local colors = require('orgmode.colors.colors')
local M = {}
local config = require('orgmode.config')

M.from_hex = function(hex_color)
   return colors.new(hex_color)
end

M.parse_hl_fg_color = function(hlgroup)
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

M.define_agenda_colors = function()
   local hl_map = M.get_agenda_hl_map()
   local keyword_colors = M.get_todo_keywords_colors()
   for type, hlname in pairs(hl_map) do
      local bold = ''
      if vim.tbl_contains(config.org_todo_keywords, type) then
         bold = ' gui=bold'
      end
      vim.cmd(string.format('hi %s guifg=%s%s', hlname, keyword_colors[type], bold))
   end
end

M.get_agenda_hl_map = function()
   return {
      TODO = 'OrgTODO',
      NEXT = 'OrgNEXT',
      DONE = 'OrgDONE',
      deadline = 'OrgAgendaDeadline',
      scheduled = 'OrgAgendaScheduled',
      scheduledPast = 'OrgAgendaScheduledPast'
   }
end

M.get_todo_keywords_colors = function()
   local error = M.parse_hl_fg_color('ErrorMsg')
   local warning = M.parse_hl_fg_color('WarningMsg')
   local ok = M.parse_hl_fg_color('diffAdded')
   local info = M.parse_hl_fg_color('diffChanged')
   if info == '' then
     info = M.parse_hl_fg_color('DiffText')
   end
   if ok == '' then
      ok = M.parse_hl_fg_color('DiffAdd')
   end

   return {
      TODO = error,
      NEXT = info,
      DONE = ok,
      deadline = M.from_hex(error):lighten_by(0.1):to_rgb(),
      scheduled = M.from_hex(ok):lighten_by(0.1):to_rgb(),
      scheduledPast = M.from_hex(warning):lighten_by(0.1):to_rgb(),
   }
end

---@param highlights table[]
---@return string
M.highlight = function(highlights)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(0, 0, hl.hlgroup, hl.line, hl.from, hl.to)
  end
end

return M

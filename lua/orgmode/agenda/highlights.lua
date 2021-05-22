local config = require('orgmode.config')
local colors = require('orgmode.colors')
local M = {}

function M.define_agenda_colors()
   local hl_map = M.get_agenda_hl_map()
   local keyword_colors = colors.get_todo_keywords_colors()
   for type, hlname in pairs(hl_map) do
      local bold = ''
      if vim.tbl_contains(config.org_todo_keywords, type) then
         bold = ' gui=bold'
      end
      vim.cmd(string.format('hi %s guifg=%s%s', hlname, keyword_colors[type], bold))
   end
end

---@return table<string, string>
function M.get_agenda_hl_map()
   return {
      TODO = 'OrgTODO',
      NEXT = 'OrgNEXT',
      DONE = 'OrgDONE',
      deadline = 'OrgAgendaDeadline',
      scheduled = 'OrgAgendaScheduled',
      scheduledPast = 'OrgAgendaScheduledPast'
   }
end

return M

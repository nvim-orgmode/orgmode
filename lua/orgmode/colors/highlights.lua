local config = require('orgmode.config')
local colors = require('orgmode.colors')
local M = {}

function M.define_agenda_colors()
   local hl_map = M.get_agenda_hl_map()
   local keyword_colors = colors.get_todo_keywords_colors()
   local todo_keywords = config:get_todo_keywords()
   for type, hlname in pairs(hl_map) do
      local bold = ''
      if vim.tbl_contains(todo_keywords.ALL, type) then
         bold = ' gui=bold'
      end
      vim.cmd(string.format('hi %s guifg=%s ctermfg=%s%s', hlname, keyword_colors[type].gui, keyword_colors[type].cterm, bold))
   end
end

function M.define_org_todo_keyword_colors()
   local keyword_colors = colors.get_todo_keywords_colors()
   local todo_keywords = config:get_todo_keywords()
   vim.cmd(string.format([[syn match OrgTODO "\<\(%s\)\>" contained]], table.concat(todo_keywords.TODO, [[\|]])))
   vim.cmd(string.format([[syn match OrgDONE "\<\(%s\)\>" contained]], table.concat(todo_keywords.DONE, [[\|]])))
   vim.cmd(string.format('hi OrgTODO guifg=%s ctermfg=%s', keyword_colors.TODO.gui, keyword_colors.TODO.cterm))
   vim.cmd(string.format('hi OrgDONE guifg=%s ctermfg=%s', keyword_colors.DONE.gui, keyword_colors.DONE.cterm))
end

function M.define_org_headline_colors()
local headline_colors = {'Title', 'Constant', 'Identifier', 'Statement', 'PreProc', 'Type', 'Special', 'String'}
local todo_keywords = config:get_todo_keywords()
local all_keywords = table.concat(todo_keywords.ALL, [[\|]])
for i, color in ipairs(headline_colors) do
   local j = i
   while j < 40 do
      vim.cmd(string.format([[syn match OrgHeadlineLevel%d "^\*\{%d}\s\+\(\<\(%s\)\>\)\?.*$" contains=OrgTODO,OrgDONE]], j, j, all_keywords))
      vim.cmd(string.format('hi default link OrgHeadlineLevel%d %s', j, color))
      j = j + 8
   end
end
end

---@return table<string, string>
function M.get_agenda_hl_map()
   return {
      TODO = 'OrgTODO',
      DONE = 'OrgDONE',
      deadline = 'OrgAgendaDeadline',
      ok = 'OrgAgendaScheduled',
      warning = 'OrgAgendaScheduledPast'
   }
end

return M

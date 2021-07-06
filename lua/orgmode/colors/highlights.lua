local config = require('orgmode.config')
local colors = require('orgmode.colors')
local M = {}

function M.define_agenda_colors()
   local keyword_colors = colors.get_todo_keywords_colors()
   local c = {
      deadline = 'OrgAgendaDeadline',
      ok = 'OrgAgendaScheduled',
      warning = 'OrgAgendaScheduledPast'
   }
   for type, hlname in pairs(c) do
      vim.cmd(string.format('hi %s_builtin guifg=%s ctermfg=%s', hlname, keyword_colors[type].gui, keyword_colors[type].cterm))
      vim.cmd(string.format('hi default link %s %s_builtin', hlname, hlname))
   end
   M.define_org_todo_keyword_colors()
end

function M.define_org_todo_keyword_colors(do_syn_match)
   local keyword_colors = colors.get_todo_keywords_colors()
   local todo_keywords = config:get_todo_keywords()
   if do_syn_match then
      vim.cmd(string.format([[syn match OrgTODO "\<\(%s\)\>" contained]], table.concat(todo_keywords.TODO, [[\|]])))
      vim.cmd(string.format([[syn match OrgDONE "\<\(%s\)\>" contained]], table.concat(todo_keywords.DONE, [[\|]])))
   end
   vim.cmd(string.format('hi OrgTODO_builtin guifg=%s ctermfg=%s gui=bold cterm=bold', keyword_colors.TODO.gui, keyword_colors.TODO.cterm))
   vim.cmd('hi default link OrgTODO OrgTODO_builtin')
   vim.cmd(string.format('hi OrgDONE_builtin guifg=%s ctermfg=%s gui=bold cterm=bold', keyword_colors.DONE.gui, keyword_colors.DONE.cterm))
   vim.cmd('hi default link OrgDONE OrgDONE_builtin')
   return M.parse_todo_keyword_faces(do_syn_match)
end

function M.define_org_headline_colors(faces)
   local headline_colors = {'Title', 'Constant', 'Identifier', 'Statement', 'PreProc', 'Type', 'Special', 'String'}
   local todo_keywords = config:get_todo_keywords()
   local all_keywords = table.concat(todo_keywords.ALL, [[\|]])
   local contains = {'OrgTODO', 'OrgDONE'}
   for _, face in pairs(faces) do
      table.insert(contains, face)
   end
   if config.org_hide_leading_stars then
      vim.cmd[[
         syntax match OrgHideLeadingStars /^\*\{2,\}/me=e-1 contained
         hi def link OrgHideLeadingStars org_hide_leading_stars
      ]]
      table.insert(contains, 'OrgHideLeadingStars')
   end
   contains = table.concat(contains, ',')
   for i, color in ipairs(headline_colors) do
      local j = i
      while j < 40 do
         vim.cmd(string.format([[syn match OrgHeadlineLevel%d "^\*\{%d}\s\+\(\<\(%s\)\>\)\?.*$" contains=%s]], j, j, all_keywords, contains))
         vim.cmd(string.format('hi default link OrgHeadlineLevel%d %s', j, color))
         j = j + 8
      end
   end
end

function M.define_highlights()
   local faces = M.define_org_todo_keyword_colors(true)
   return M.define_org_headline_colors(faces)
end

function M.parse_todo_keyword_faces(do_syn_match)
   local opts = {
      underline = {
         type = vim.o.termguicolors and 'gui' or 'cterm',
         valid = 'on',
         result = 'underline'
      },
      weight = {
         type = vim.o.termguicolors and 'gui' or 'cterm',
         valid = 'bold'
      },
      foreground = {
         type = vim.o.termguicolors and 'guifg' or 'ctermfg',
      },
      background = {
         type = vim.o.termguicolors and 'guibg' or 'ctermbg',
      },
      slant = {
         type = vim.o.termguicolors and 'gui' or 'cterm',
         valid = 'italic'
      }
   }

   local result = {}

   for name, values in pairs(config.org_todo_keyword_faces) do
      local parts = vim.split(values, ':', true)
      local hl_opts = {}
      for _, part in ipairs(parts) do
         local faces = vim.split(vim.trim(part), ' ')
         if #faces == 2 then
            local opt_name = vim.trim(faces[1])
            local opt_value = vim.trim(faces[2])
            opt_value = opt_value:gsub('^"*', ''):gsub('"*$', '')
            local opt = opts[opt_name]
            if opt and (not opt.valid or opt.valid == opt_value) then
               if not hl_opts[opt.type] then
                  hl_opts[opt.type] = {}
               end
               table.insert(hl_opts[opt.type], opt.result or opt_value)
            end
         end
      end
      if not vim.tbl_isempty(hl_opts) then
         local hl_name = 'OrgKeywordFace'..name
         local hl = ''
         for hl_item, hl_values in pairs(hl_opts) do
            hl = hl..' '..hl_item..'='..table.concat(hl_values, ',')
         end
         if do_syn_match then
            vim.cmd(string.format([[syn match %s "\<%s\>" contained]], hl_name, name))
         end
         vim.cmd(string.format('hi %s %s', hl_name, hl))
         result[name] = hl_name
      end
   end

   return result
end

---@return table<string, string>
function M.get_agenda_hl_map()
   local faces = M.parse_todo_keyword_faces()
   return vim.tbl_extend('force', {
      TODO = 'OrgTODO',
      DONE = 'OrgDONE',
      deadline = 'OrgAgendaDeadline',
      ok = 'OrgAgendaScheduled',
      warning = 'OrgAgendaScheduledPast'
   }, faces)
end

return M

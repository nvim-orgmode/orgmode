local config = require('orgmode.config')
local colors = require('orgmode.colors')
local M = {}

function M.link_ts_highlights()
  local links = {
    OrgTSTimestampActive = 'PreProc',
    OrgTSTimestampInactive = 'Comment',
    OrgTSHeadlineLevel1 = 'OrgHeadlineLevel1',
    OrgTSHeadlineLevel2 = 'OrgHeadlineLevel2',
    OrgTSHeadlineLevel3 = 'OrgHeadlineLevel3',
    OrgTSHeadlineLevel4 = 'OrgHeadlineLevel4',
    OrgTSHeadlineLevel5 = 'OrgHeadlineLevel5',
    OrgTSHeadlineLevel6 = 'OrgHeadlineLevel6',
    OrgTSHeadlineLevel7 = 'OrgHeadlineLevel7',
    OrgTSHeadlineLevel8 = 'OrgHeadlineLevel8',
    OrgTSBullet = 'Identifier',
    OrgTSCheckbox = 'PreProc',
    OrgTSCheckboxHalfChecked = 'OrgTSCheckbox',
    OrgTSCheckboxUnchecked = 'OrgTSCheckbox',
    OrgTSCheckboxChecked = 'OrgTSCheckbox',
    OrgTSPropertyDrawer = 'Constant',
    OrgTSDrawer = 'Constant',
    OrgTSTag = 'Function',
    OrgTSPlan = 'Constant',
    OrgTSComment = 'Comment',
    OrgTSDirective = 'Comment',
    OrgTSBlock = 'Comment',
    OrgTSLatex = 'Statement',
  }

  for src, def in pairs(links) do
    vim.cmd(string.format([[hi link @%s %s]], src, src))
    vim.cmd(string.format([[hi def link %s %s]], src, def))
  end
end

function M.link_highlights()
  local links = {
    OrgEditSrcHighlight = 'Visual',
  }

  for src, def in pairs(links) do
    vim.cmd(string.format([[hi def link %s %s]], src, def))
  end
end

function M.define_agenda_colors()
  local keyword_colors = colors.get_todo_keywords_colors()
  local c = {
    deadline = 'OrgAgendaDeadline',
    ok = 'OrgAgendaScheduled',
    warning = 'OrgAgendaScheduledPast',
  }
  for type, hlname in pairs(c) do
    vim.cmd(
      string.format('hi %s_builtin guifg=%s ctermfg=%s', hlname, keyword_colors[type].gui, keyword_colors[type].cterm)
    )
    vim.cmd(string.format('hi default link %s %s_builtin', hlname, hlname))
  end
  M.define_org_todo_keyword_colors()
end

function M.define_org_todo_keyword_colors(do_syn_match)
  local keyword_colors = colors.get_todo_keywords_colors()
  local ts_highlights_enabled = config:ts_highlights_enabled()
  if not ts_highlights_enabled and do_syn_match then
    local todo_keywords = config:get_todo_keywords()
    vim.cmd(string.format([[syn match OrgTODO "\<\(%s\)\>" contained]], table.concat(todo_keywords.TODO, [[\|]])))
    vim.cmd(string.format([[syn match OrgDONE "\<\(%s\)\>" contained]], table.concat(todo_keywords.DONE, [[\|]])))
  end
  vim.cmd(
    string.format(
      'hi OrgTODO_builtin guifg=%s ctermfg=%s gui=bold cterm=bold',
      keyword_colors.TODO.gui,
      keyword_colors.TODO.cterm
    )
  )
  vim.cmd('hi default link OrgTODO OrgTODO_builtin')
  vim.cmd('hi link @OrgTODO OrgTODO')
  vim.cmd(
    string.format(
      'hi OrgDONE_builtin guifg=%s ctermfg=%s gui=bold cterm=bold',
      keyword_colors.DONE.gui,
      keyword_colors.DONE.cterm
    )
  )
  vim.cmd('hi default link OrgDONE OrgDONE_builtin')
  vim.cmd('hi link @OrgDONE OrgDONE')
  return M.parse_todo_keyword_faces(do_syn_match)
end

function M.define_org_headline_colors(faces)
  local headline_colors = { 'Title', 'Constant', 'Identifier', 'Statement', 'PreProc', 'Type', 'Special', 'String' }
  local ts_highlights_enabled = config:ts_highlights_enabled()
  local all_keywords = ''
  if not ts_highlights_enabled then
    local todo_keywords = config:get_todo_keywords()
    all_keywords = table.concat(todo_keywords.ALL, [[\|]])
  end
  local contains = { 'OrgTODO', 'OrgDONE' }
  for _, face in pairs(faces) do
    table.insert(contains, face)
  end
  if config.org_hide_leading_stars then
    if not ts_highlights_enabled then
      vim.cmd([[syn match OrgHideLeadingStars /^\*\{2,\}/me=e-1 contained]])
    end
    vim.cmd([[hi default OrgHideLeadingStars ctermfg=0 guifg=bg]])
    table.insert(contains, 'OrgHideLeadingStars')
  end
  for i, color in ipairs(headline_colors) do
    local j = i
    while j < 40 do
      if not ts_highlights_enabled then
        vim.cmd(
          string.format(
            [[syn match OrgHeadlineLevel%d "^\*\{%d}\s\+\(\<\(%s\)\>\)\?.*$" contains=%s]],
            j,
            j,
            all_keywords,
            table.concat(contains, ',')
          )
        )
      end
      vim.cmd(string.format('hi default link OrgHeadlineLevel%d %s', j, color))
      j = j + 8
    end
  end
end

function M.define_highlights()
  if config:ts_highlights_enabled() then
    M.link_ts_highlights()
  end

  M.link_highlights()

  local faces = M.define_org_todo_keyword_colors(true)
  return M.define_org_headline_colors(faces)
end

function M.parse_todo_keyword_faces(do_syn_match)
  local ts_highlights_enabled = config:ts_highlights_enabled()
  local opts = {
    underline = {
      type = vim.o.termguicolors and 'gui' or 'cterm',
      valid = 'on',
      result = 'underline',
    },
    weight = {
      type = vim.o.termguicolors and 'gui' or 'cterm',
      valid = 'bold',
    },
    foreground = {
      type = vim.o.termguicolors and 'guifg' or 'ctermfg',
    },
    background = {
      type = vim.o.termguicolors and 'guibg' or 'ctermbg',
    },
    slant = {
      type = vim.o.termguicolors and 'gui' or 'cterm',
      valid = 'italic',
    },
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
      local hl_name = 'OrgKeywordFace' .. name:gsub('%-', '')
      local hl = ''
      for hl_item, hl_values in pairs(hl_opts) do
        hl = hl .. ' ' .. hl_item .. '=' .. table.concat(hl_values, ',')
      end
      if not ts_highlights_enabled and do_syn_match then
        vim.cmd(string.format([[syn match %s "\<%s\>" contained]], hl_name, name))
      end
      vim.cmd(string.format('hi %s %s', hl_name, hl))
      vim.cmd(string.format([[hi link @%s %s]], hl_name, hl_name))
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
    warning = 'OrgAgendaScheduledPast',
  }, faces)
end

return M

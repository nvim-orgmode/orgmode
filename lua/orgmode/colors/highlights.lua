local config = require('orgmode.config')
local colors = require('orgmode.colors')
local utils = require('orgmode.utils')
local M = {}

function M.define_highlights()
  M.link_highlights()
  M.define_agenda_colors()
  M.define_org_todo_keyword_colors()
  M.define_todo_keyword_faces()
end

function M.link_highlights()
  local links = {
    -- Headlines
    ['@org.headline.level1'] = 'Title',
    ['@org.headline.level2'] = 'Constant',
    ['@org.headline.level3'] = 'Identifier',
    ['@org.headline.level4'] = 'Statement',
    ['@org.headline.level5'] = 'PreProc',
    ['@org.headline.level6'] = 'Type',
    ['@org.headline.level7'] = 'Special',
    ['@org.headline.level8'] = 'String',

    ['@org.priority.highest'] = '@comment.error',

    -- Headline tags
    ['@org.tag'] = '@tag.attribute',

    -- Headline plan
    ['@org.plan'] = 'Constant',

    -- Timestamps
    ['@org.timestamp.active'] = '@keyword',
    ['@org.timestamp.inactive'] = '@comment',
    -- Lists/Checkboxes
    ['@org.bullet'] = '@markup.list',
    ['@org.checkbox'] = '@markup.list.unchecked',
    ['@org.checkbox.halfchecked'] = '@markup.list.unchecked',
    ['@org.checkbox.checked'] = '@markup.list.checked',

    -- Drawers
    ['@org.properties'] = '@property',
    ['@org.properties.name'] = '@property',
    ['@org.drawer'] = '@property',

    ['@org.comment'] = '@comment',
    ['@org.directive'] = '@comment',
    ['@org.block'] = '@comment',

    -- Markup
    ['@org.bold'] = '@markup.strong',
    ['@org.bold.delimiter'] = '@markup.strong',
    ['@org.italic'] = '@markup.italic',
    ['@org.italic.delimiter'] = '@markup.italic',
    ['@org.strikethrough'] = '@markup.strikethrough',
    ['@org.strikethrough.delimiter'] = '@markup.strikethrough',
    ['@org.underline'] = '@markup.underline',
    ['@org.underline.delimiter'] = '@markup.underline',
    ['@org.code'] = '@markup.raw',
    ['@org.code.delimiter'] = '@markup.raw',
    ['@org.verbatim'] = '@markup.raw',
    ['@org.verbatim.delimiter'] = '@markup.raw',
    ['@org.hyperlink'] = '@markup.link.url',
    ['@org.latex'] = '@markup.math',
    ['@org.latex_env'] = '@markup.environment',
    -- Other
    ['@org.table.delimiter'] = '@punctuation.special',
    ['@org.table.heading'] = '@markup.heading',
    ['@org.edit_src'] = 'Visual',
  }

  if not utils.has_version_10() then
    links = vim.tbl_extend('force', links, {
      ['@org.priority.highest'] = 'Error',
      ['@org.timestamp.active'] = 'PreProc',
      ['@org.timestamp.inactive'] = 'Comment',
      ['@org.bullet'] = 'Identifier',
      ['@org.checkbox'] = 'PreProc',
      ['@org.checkbox.halfchecked'] = 'PreProc',
      ['@org.checkbox.checked'] = 'PreProc',
      ['@org.properties'] = 'Constant',
      ['@org.properties.name'] = 'Constant',
      ['@org.drawer'] = 'Constant',
      ['@org.tag'] = 'Function',
      ['@org.plan'] = 'Constant',
      ['@org.comment'] = 'Comment',
      ['@org.directive'] = 'Comment',
      ['@org.block'] = 'Comment',
      ['@org.latex'] = 'Statement',
      ['@org.latex_env'] = 'Statement',
      ['@org.hyperlink'] = 'Underlined',
      ['@org.code'] = 'String',
      ['@org.code.delimiter'] = 'String',
      ['@org.verbatim'] = 'String',
      ['@org.verbatim.delimiter'] = 'String',
      ['@org.bold'] = { bold = true },
      ['@org.bold.delimiter'] = { bold = true },
      ['@org.italic'] = { italic = true },
      ['@org.italic.delimiter'] = { italic = true },
      ['@org.strikethrough'] = { strikethrough = true },
      ['@org.strikethrough.delimiter'] = { strikethrough = true },
      ['@org.underline'] = { underline = true },
      ['@org.underline.delimiter'] = { underline = true },
      ['@org.table.delimiter'] = '@punctuation',
      ['@org.table.heading'] = '@function',
    })
  end

  for src, def in pairs(links) do
    if type(def) == 'table' then
      def.default = true
      vim.api.nvim_set_hl(0, src, def)
    else
      vim.api.nvim_set_hl(0, src, { link = def, default = true })
    end
  end
end

function M.define_agenda_colors()
  local keyword_colors = colors.get_todo_keywords_colors()
  local c = {
    deadline = '@org.agenda.deadline',
    ok = '@org.agenda.scheduled',
    warning = '@org.agenda.scheduled_past',
  }
  for type, hlname in pairs(c) do
    vim.cmd(
      string.format('hi default %s guifg=%s ctermfg=%s', hlname, keyword_colors[type].gui, keyword_colors[type].cterm)
    )
  end

  M.define_org_todo_keyword_colors()
end

function M.define_org_todo_keyword_colors()
  local keyword_colors = colors.get_todo_keywords_colors()
  vim.cmd(
    ('hi default @org.keyword.todo guifg=%s ctermfg=%s gui=bold cterm=bold'):format(
      keyword_colors.TODO.gui,
      keyword_colors.TODO.cterm
    )
  )

  vim.cmd(
    ('hi default @org.keyword.done guifg=%s ctermfg=%s gui=bold cterm=bold'):format(
      keyword_colors.DONE.gui,
      keyword_colors.DONE.cterm
    )
  )
  vim.cmd([[hi default @org.leading_stars ctermfg=0 guifg=bg]])
end

function M.define_todo_keyword_faces()
  local opts = {
    underline = {
      type = vim.o.termguicolors and 'gui' or 'cterm',
      is_valid = function(value)
        return value == 'on'
      end,
      result = 'underline',
    },
    weight = {
      type = vim.o.termguicolors and 'gui' or 'cterm',
      is_valid = function(value)
        return value == 'bold'
      end,
    },
    foreground = {
      type = vim.o.termguicolors and 'guifg' or 'ctermfg',
      is_valid = function(value)
        if vim.o.termguicolors then
          return true
        end
        return value:sub(1, 1) ~= '#'
      end,
    },
    background = {
      type = vim.o.termguicolors and 'guibg' or 'ctermbg',
      is_valid = function(value)
        if vim.o.termguicolors then
          return true
        end
        return value:sub(1, 1) ~= '#'
      end,
    },
    slant = {
      type = vim.o.termguicolors and 'gui' or 'cterm',
      is_valid = function(value)
        return value == 'italic'
      end,
    },
  }

  local result = {}

  for name, values in pairs(config.org_todo_keyword_faces) do
    local parts = vim.split(values, ':', { plain = true })
    local hl_opts = {}
    for _, part in ipairs(parts) do
      local faces = vim.split(vim.trim(part), ' ')
      if #faces == 2 then
        local opt_name = vim.trim(faces[1])
        local opt_value = vim.trim(faces[2])
        opt_value = opt_value:gsub('^"*', ''):gsub('"*$', '')
        local opt = opts[opt_name]
        if opt and opt.is_valid(opt_value) then
          if not hl_opts[opt.type] then
            hl_opts[opt.type] = {}
          end
          table.insert(hl_opts[opt.type], opt.result or opt_value)
        end
      end
    end
    if not vim.tbl_isempty(hl_opts) then
      local hl_name = '@org.keyword.face.' .. name:gsub('%-', '')
      local hl = ''
      for hl_item, hl_values in pairs(hl_opts) do
        hl = hl .. ' ' .. hl_item .. '=' .. table.concat(hl_values, ',')
      end
      vim.cmd(string.format('hi default %s %s', hl_name, hl))
      result[name] = hl_name
    end
  end

  return result
end

---@return table<string, string>
function M.get_agenda_hl_map()
  local faces = M.define_todo_keyword_faces()
  return vim.tbl_extend('force', {
    TODO = '@org.keyword.todo',
    DONE = '@org.keyword.done',
    deadline = '@org.agenda.deadline',
    ok = '@org.agenda.scheduled',
    warning = '@org.agenda.scheduled_past',
    priority = config:get_priorities(),
  }, faces)
end

return M

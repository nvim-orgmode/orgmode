local colors = require('orgmode.colors')
local highlights = require('orgmode.colors.highlights')
local config = require('orgmode.config')

describe('Colors', function()
  it('should lighten the color', function()
    local color = colors.from_hex('#ffffff')
    assert.are.same('#ffffff', color:to_rgb())
    color = color:darken_by(0.5)
    assert.are.same('#808080', color:to_rgb())
    color = color:lighten_by(0.25)
    assert.are.same('#9f9f9f', color:to_rgb())
  end)

  it('should get appropriate fg color from hl group', function()
    vim.cmd([[hi OrgTestParse guifg=#FF0000]])
    local parsed_color = colors.parse_hl_fg_color('OrgTestParse')
    assert.are.same('#FF0000', parsed_color:upper())

    vim.cmd([[hi OrgTestParse guibg=#FF8888]])
    parsed_color = colors.parse_hl_fg_color('OrgTestParse')
    assert.are.same('#FF8888', parsed_color:upper())

    vim.cmd([[hi OrgTestParse guifg=#FFFFFF guibg=#00FF00]])
    parsed_color = colors.parse_hl_fg_color('OrgTestParse')
    assert.are.same('#00FF00', parsed_color:upper())

    vim.cmd([[hi OrgTestParse guifg=#FFFFFF guibg=#00FF00 gui=reverse]])
    parsed_color = colors.parse_hl_fg_color('OrgTestParse')
    assert.are.same('#FFFFFF', parsed_color:upper())

    vim.cmd([[hi clear OrgTestParse]])
  end)

  it('should fallback to default colors if none provided for todo colors', function()
    vim.cmd([[
      hi clear Error
      hi clear ErrorMsg
      hi clear WarningMsg
      hi clear diffAdded
      hi clear DiffAdd
    ]])
    local todo_keywords_colors = colors.get_todo_keywords_colors()
    assert.are.same({
      DONE = { gui = '#00FF00', cterm = 2 },
      TODO = { gui = '#FF0000', cterm = 1 },
      deadline = { gui = '#ff1a1a', cterm = 9 },
      ok = { gui = '#1aff1a', cterm = 10 },
      warning = { gui = '#ff981a', cterm = 11 },
    }, todo_keywords_colors)
  end)

  it('should parse todo keyword faces', function()
    local get_color_opt = function(hlgroup, name, type)
      return vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(hlgroup)), name, type):lower()
    end
    config:extend({
      org_todo_keyword_faces = {
        NEXT = ':foreground "blue" :underline on :weight bold :background red :slant italic',
        CANCELED = ':foreground green :slant italic',
        ['IN-PROGRESS'] = ':foreground red :weight bold',
      },
    })

    local result = highlights.define_todo_keyword_faces()

    assert.are.same({
      NEXT = '@org.keyword.face.NEXT',
      CANCELED = '@org.keyword.face.CANCELED',
      ['IN-PROGRESS'] = '@org.keyword.face.INPROGRESS',
    }, result)

    assert.are.same('red', get_color_opt('@org.keyword.face.NEXT', 'bg', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.NEXT', 'bg', 'cterm'))
    assert.are.same('blue', get_color_opt('@org.keyword.face.NEXT', 'fg', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.NEXT', 'fg', 'cterm'))
    assert.are.same('1', get_color_opt('@org.keyword.face.NEXT', 'bold', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.NEXT', 'bold', 'cterm'))
    assert.are.same('1', get_color_opt('@org.keyword.face.NEXT', 'italic', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.NEXT', 'italic', 'cterm'))
    assert.are.same('1', get_color_opt('@org.keyword.face.NEXT', 'underline', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.NEXT', 'underline', 'cterm'))

    assert.are.same('green', get_color_opt('@org.keyword.face.CANCELED', 'fg', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'fg', 'cterm'))
    assert.are.same('1', get_color_opt('@org.keyword.face.CANCELED', 'italic', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'italic', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'bg', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'bg', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'bold', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'bold', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'underline', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'underline', 'cterm'))

    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'bg', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'bg', 'cterm'))
    assert.are.same('red', get_color_opt('@org.keyword.face.INPROGRESS', 'fg', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'fg', 'cterm'))
    assert.are.same('1', get_color_opt('@org.keyword.face.INPROGRESS', 'bold', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'bold', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'italic', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'italic', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'underline', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'underline', 'cterm'))

    vim.cmd([[
      hi clear @org.keyword.face.NEXT
      hi clear @org.keyword.face.CANCELED
      hi clear @org.keyword.face.INPROGRESS
    ]])

    vim.o.termguicolors = false
    result = highlights.define_todo_keyword_faces()

    assert.are.same({
      NEXT = '@org.keyword.face.NEXT',
      CANCELED = '@org.keyword.face.CANCELED',
      ['IN-PROGRESS'] = '@org.keyword.face.INPROGRESS',
    }, result)

    assert.are.same('9', get_color_opt('@org.keyword.face.NEXT', 'bg', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.NEXT', 'bg', 'gui'))
    assert.are.same('12', get_color_opt('@org.keyword.face.NEXT', 'fg', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.NEXT', 'fg', 'gui'))
    assert.are.same('1', get_color_opt('@org.keyword.face.NEXT', 'bold', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.NEXT', 'bold', 'gui'))
    assert.are.same('1', get_color_opt('@org.keyword.face.NEXT', 'italic', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.NEXT', 'italic', 'gui'))
    assert.are.same('1', get_color_opt('@org.keyword.face.NEXT', 'underline', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.NEXT', 'underline', 'gui'))

    assert.are.same('10', get_color_opt('@org.keyword.face.CANCELED', 'fg', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'fg', 'gui'))
    assert.are.same('1', get_color_opt('@org.keyword.face.CANCELED', 'italic', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'italic', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'bg', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'bg', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'bold', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'bold', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'underline', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.CANCELED', 'underline', 'cterm'))

    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'bg', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'bg', 'gui'))
    assert.are.same('9', get_color_opt('@org.keyword.face.INPROGRESS', 'fg', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'fg', 'gui'))
    assert.are.same('1', get_color_opt('@org.keyword.face.INPROGRESS', 'bold', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'bold', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'italic', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'italic', 'gui'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'underline', 'cterm'))
    assert.are.same('', get_color_opt('@org.keyword.face.INPROGRESS', 'underline', 'gui'))
  end)
end)

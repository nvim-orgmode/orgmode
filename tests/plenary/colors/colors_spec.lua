local colors = require('orgmode.colors')

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
    vim.cmd[[hi OrgTestParse guifg=#FF0000]]
    local parsed_color = colors.parse_hl_fg_color('OrgTestParse')
    assert.are.same('#FF0000', parsed_color)

    vim.cmd[[hi OrgTestParse guibg=#FF8888]]
    parsed_color = colors.parse_hl_fg_color('OrgTestParse')
    assert.are.same('#FF8888', parsed_color)

    vim.cmd[[hi OrgTestParse guifg=#FFFFFF guibg=#00FF00]]
    parsed_color = colors.parse_hl_fg_color('OrgTestParse')
    assert.are.same('#00FF00', parsed_color)

    vim.cmd[[hi OrgTestParse guifg=#FFFFFF guibg=#00FF00 gui=reverse]]
    parsed_color = colors.parse_hl_fg_color('OrgTestParse')
    assert.are.same('#FFFFFF', parsed_color)

    vim.cmd[[hi clear OrgTestParse]]
  end)

  it('should fallback to default colors if none provided for todo colors', function()
    vim.cmd[[
      hi clear Error
      hi clear ErrorMsg
      hi clear WarningMsg
      hi clear diffAdded
      hi clear DiffAdd
    ]]
    local todo_keywords_colors = colors.get_todo_keywords_colors()
    assert.are.same({
      DONE = "#00FF00",
      TODO = "#FF0000",
      deadline = "#ff1a1a",
      ok = "#1aff1a",
      warning = "#ff981a"
    }, todo_keywords_colors)
  end)
end)

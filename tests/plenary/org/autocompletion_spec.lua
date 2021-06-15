local mock = require('luassert.mock')
local Autocompletion = require('orgmode.org.autocompletion')

local function mock_line(api, content)
  api.nvim_get_current_line.returns(content)
  api.nvim_call_function.returns(content:len() + 5)
end

describe('Autocompletion', function()
  it('should properly find start offset for omni autocompletion', function()
    local api = mock(vim.api, true)
    mock_line(api, '')
    local result = Autocompletion.omni(1, '')
    assert.are.same(0, result)

    mock_line(api, '* ')
    result = Autocompletion.omni(1, '')
    assert.are.same(2, result)

    mock_line(api, '* TO')
    result = Autocompletion.omni(1, '')
    assert.are.same(2, result)

    mock_line(api, '* TODO')
    result = Autocompletion.omni(1, '')
    assert.are.same(2, result)

    mock_line(api, '* TODO some text ')
    result = Autocompletion.omni(1, '')
    assert.are.same(-1, result)

    mock_line(api, '* TODO tags goes at the end :')
    result = Autocompletion.omni(1, '')
    assert.are.same(28, result)

    mock_line(api, '* TODO tags goes at the end :SOMET')
    result = Autocompletion.omni(1, '')
    assert.are.same(28, result)
    mock_line(api, '* TODO tags goes at the end :SOMETAG:')
    result = Autocompletion.omni(1, '')
    assert.are.same(36, result)

    mock_line(api, '#')
    result = Autocompletion.omni(1, '')
    assert.are.same(0, result)

    mock_line(api, '#+')
    result = Autocompletion.omni(1, '')
    assert.are.same(0, result)

    mock_line(api, '#+AR')
    result = Autocompletion.omni(1, '')
    assert.are.same(0, result)

    mock_line(api, ':')
    result = Autocompletion.omni(1, '')
    assert.are.same(0, result)

    mock_line(api, '  :')
    result = Autocompletion.omni(1, '')
    assert.are.same(2, result)

    mock_line(api, '  :PROP')
    result = Autocompletion.omni(1, '')
    assert.are.same(2, result)

    mock_line(api, '  :PROPERTI')
    result = Autocompletion.omni(1, '')
    assert.are.same(2, result)

    mock.revert(api)
  end)

  it('should properly return results for base', function()
  end)
end)

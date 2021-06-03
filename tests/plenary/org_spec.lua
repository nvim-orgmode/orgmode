local mock = require('luassert.mock')
local parser = require('orgmode.parser')

describe('Org file', function()
  it('should properly add new properties to a headline', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '* TODO Another todo'
    }
    local parsed = parser.parse(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(true)
    local headline = parsed:get_item(1)
    headline:add_properties({ CATEGORY = 'testing' })
    assert.stub(api.nvim_call_function).was_called_with('append', { 2, {
      '  :PROPERTIES:',
      '  :CATEGORY: testing',
      '  :END:'
    }})
    mock.revert(api)
  end)

  it('should properly append to existing properties', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '  :PROPERTIES:',
      '  :CATEGORY: Testing',
      '  :END:',
      '* TODO Another todo'
    }
    local parsed = parser.parse(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(true)
    local headline = parsed:get_item(1)
    headline:add_properties({ CUSTOM_ID = '1' })
    assert.stub(api.nvim_call_function).was.called_with('append', { 3, '  :CUSTOM_ID: 1'})
    mock.revert(api)
  end)

  it('should properly update existing property', function()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '  :PROPERTIES:',
      '  :CATEGORY: Testing',
      '  :END:',
      '* TODO Another todo'
    }
    local parsed = parser.parse(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(true)
    local headline = parsed:get_item(1)
    headline:add_properties({ CATEGORY = 'Newvalue' })
    assert.stub(api.nvim_call_function).was.called_with('setline', { 4, '  :CATEGORY: Newvalue'})
    mock.revert(api)
  end)
end)

local helpers = require('tests.plenary.ui.helpers')
local ts_org = require('orgmode.treesitter')
local mock = require('luassert.mock')
local File = require('orgmode.parser.file')
local Date = require('orgmode.objects.date')

describe('Org file', function()
  it('should properly add new properties to a section', function()
    helpers.load_file_content({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '* TODO Another todo',
    })

    local headline = ts_org.find_headline('test orgmode')
    assert.are.same('Test orgmode', headline:title())
    headline:set_property('CATEGORY', 'testing')

    assert.are.same({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '  :PROPERTIES:',
      '  :CATEGORY: testing',
      '  :END:',
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 8, false))
  end)

  it('should properly append to existing properties', function()
    helpers.load_file_content({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '  :PROPERTIES:',
      '  :CATEGORY: Testing',
      '  :END:',
      '* TODO Another todo',
    })
    local headline = ts_org.find_headline('test orgmode')
    assert.are.same('Test orgmode', headline:title())
    headline:set_property('CUSTOM_ID', '1')

    assert.are.same({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '  :PROPERTIES:',
      '  :CATEGORY: Testing',
      '  :CUSTOM_ID: 1',
      '  :END:',
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 8, false))
  end)
  --
  it('should properly update existing property', function()
    helpers.load_file_content({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '  :PROPERTIES:',
      '  :CATEGORY: Testing',
      '  :CUSTOM_ID: 1',
      '  :END:',
      '* TODO Another todo',
    })
    local headline = ts_org.find_headline('test orgmode')
    assert.are.same('Test orgmode', headline:title())
    headline:set_property('CATEGORY', 'Updated')

    assert.are.same({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '  :PROPERTIES:',
      '  :CATEGORY: Updated',
      '  :CUSTOM_ID: 1',
      '  :END:',
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 8, false))
  end)

  it('should add closed date to section if it does not exist', function()
    local now = Date.now():to_string()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[2])
    local section = parsed:get_section(1)
    section:add_closed_date()
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      2,
      'DEADLINE: <2021-05-10 11:00> CLOSED: [' .. now .. ']',
    })
    mock.revert(api)

    lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00> CLOSED: [' .. now .. ']',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    api = mock(vim.api, true)
    section = parsed:get_section(1)
    local no_result = section:add_closed_date()
    assert.are.same(nil, no_result)
    mock.revert(api)
  end)

  it('should remove closed date from section if it exists', function()
    local now = Date.now():to_string()
    local lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00> CLOSED: [' .. now .. ']',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[2])
    local section = parsed:get_section(1)
    local result = section:remove_closed_date()
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      2,
      'DEADLINE: <2021-05-10 11:00>',
    })
    mock.revert(api)

    lines = {
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    section = parsed:get_section(1)
    result = section:remove_closed_date()
    assert.are.same(nil, result)

    lines = {
      '* TODO Test orgmode :WORK:',
      'CLOSED: [' .. now .. ']',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[2])
    section = parsed:get_section(1)
    api.nvim_get_current_buf.returns(4)
    section:remove_closed_date()
    assert.stub(api.nvim_call_function).was.called_with('deletebufline', { 4, 2 })
    mock.revert(api)
  end)

  it('should add and update deadline date', function()
    local deadline_date = Date.from_string('2021-08-18 Wed')
    local lines = {
      '* TODO Test orgmode :WORK:',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(true)
    local section = parsed:get_section(1)
    local result = section:add_deadline_date(deadline_date)
    assert.are.same(true, result)
    assert.stub(api.nvim_call_function).was.called_with('append', {
      1,
      '  DEADLINE: <2021-08-18 Wed>',
    })
    mock.revert(api)

    lines = {
      '* TODO Test orgmode :WORK:',
      '  DEADLINE: <2021-08-18 Wed>',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    api = mock(vim.api, true)
    section = parsed:get_section(1)
    api.nvim_call_function.returns('  DEADLINE: <2021-08-18 Wed>')
    result = section:add_deadline_date(deadline_date:add({ day = 2 }))
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      2,
      '  DEADLINE: <2021-08-20 Fri>',
    })
    mock.revert(api)
  end)

  it('should add and update scheduled date', function()
    local scheduled_date = Date.from_string('2021-08-18 Wed')
    local lines = {
      '* TODO Test orgmode :WORK:',
      '* TODO Another todo',
    }
    local parsed = File.from_content(lines, 'work')
    local api = mock(vim.api, true)
    api.nvim_call_function.returns(true)
    local section = parsed:get_section(1)
    local result = section:add_scheduled_date(scheduled_date)
    assert.are.same(true, result)
    assert.stub(api.nvim_call_function).was.called_with('append', {
      1,
      '  SCHEDULED: <2021-08-18 Wed>',
    })
    mock.revert(api)

    lines = {
      '* TODO Test orgmode :WORK:',
      '  DEADLINE: <2021-08-18 Wed>',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[2])
    section = parsed:get_section(1)
    result = section:add_scheduled_date(scheduled_date:add({ day = 2 }))
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      2,
      '  DEADLINE: <2021-08-18 Wed> SCHEDULED: <2021-08-20 Fri>',
    })
    mock.revert(api)

    lines = {
      '* TODO Test orgmode :WORK:',
      '  DEADLINE: <2021-08-18 Wed> SCHEDULED: <2021-08-18 Wed>',
      '* TODO Another todo',
    }
    parsed = File.from_content(lines, 'work')
    api = mock(vim.api, true)
    api.nvim_call_function.returns(lines[2])
    section = parsed:get_section(1)
    api.nvim_call_function.returns('  DEADLINE: <2021-08-18 Wed> SCHEDULED: <2021-08-18 Wed>')
    result = section:add_scheduled_date(scheduled_date:add({ day = 4 }))
    assert.stub(api.nvim_call_function).was.called_with('setline', {
      2,
      '  DEADLINE: <2021-08-18 Wed> SCHEDULED: <2021-08-22 Sun>',
    })
    mock.revert(api)
  end)
end)

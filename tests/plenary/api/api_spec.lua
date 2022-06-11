local helpers = require('tests.plenary.ui.helpers')
local api = require('orgmode.api')

describe('Api', function()
  it('should parse current file through api', function()
    local file = helpers.load_file_content({
      '#TITLE: First file',
      '',
      '* TODO Test orgmode :WORK:OFFICE:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '* DONE Some task',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '  Unrelated date <2022-06-11 Sat 23:15>',
    })

    assert.is.True(#api.load() > 1)
    local current_file = api.current()
    assert.are.same(false, current_file.is_archive_file)
    assert.are.same(file, current_file.filename)
    assert.are.same(current_file.category, vim.fn.fnamemodify(file, ':p:t:r'))
    assert.are.same(3, #current_file.headlines)
    assert.are.same('Test orgmode', current_file.headlines[1].title)
    assert.are.same('* TODO Test orgmode :WORK:OFFICE:', current_file.headlines[1].line)
    assert.are.same({ 'WORK', 'OFFICE' }, current_file.headlines[1].all_tags)
    assert.are.same({ 'WORK', 'OFFICE' }, current_file.headlines[1].tags)
    assert.are.same(1, #current_file.headlines[1].headlines)
    assert.are.same('TODO', current_file.headlines[1].todo_value)
    assert.are.same('TODO', current_file.headlines[1].todo_type)
    assert.are.same(3, current_file.headlines[1].position.start_line)
    assert.are.same(1, current_file.headlines[1].position.start_col)
    assert.are.same(6, current_file.headlines[1].position.end_line)
    assert.are.same(0, current_file.headlines[1].position.end_col)
    assert.is.Nil(current_file.headlines[1].parent)
    assert.are.same('2021-07-21 Wed 22:02', current_file.headlines[1].deadline:to_string())
    assert.Is.Nil(current_file.headlines[1].scheduled)
    assert.Is.Nil(current_file.headlines[1].closed)
    assert.are.same({}, current_file.headlines[1].dates)

    assert.are.same('Second level', current_file.headlines[2].title)
    assert.are.same(0, #current_file.headlines[2].headlines)
    assert.are.same({ 'WORK', 'OFFICE', 'NESTEDTAG' }, current_file.headlines[2].all_tags)
    assert.are.same({ 'NESTEDTAG' }, current_file.headlines[2].tags)
    assert.are.same('TODO', current_file.headlines[2].todo_value)
    assert.are.same('TODO', current_file.headlines[2].todo_type)
    assert.are.same(5, current_file.headlines[2].position.start_line)
    assert.are.same(1, current_file.headlines[2].position.start_col)
    assert.are.same(6, current_file.headlines[2].position.end_line)
    assert.are.same(0, current_file.headlines[2].position.end_col)
    assert.are.same(current_file.headlines[1], current_file.headlines[2].parent)

    assert.are.same('Some task', current_file.headlines[3].title)
    assert.are.same(0, #current_file.headlines[3].headlines)
    assert.are.same({}, current_file.headlines[3].all_tags)
    assert.are.same({}, current_file.headlines[3].tags)
    assert.are.same('DONE', current_file.headlines[3].todo_value)
    assert.are.same('DONE', current_file.headlines[3].todo_type)
    assert.are.same(7, current_file.headlines[3].position.start_line)
    assert.are.same(1, current_file.headlines[3].position.start_col)
    assert.are.same(9, current_file.headlines[3].position.end_line)
    assert.are.same(39, current_file.headlines[3].position.end_col)
    assert.is.Nil(current_file.headlines[3].parent)
    assert.are.same('2021-07-21 Wed 22:02', current_file.headlines[3].deadline:to_string())
    assert.Is.Nil(current_file.headlines[3].scheduled)
    assert.Is.Nil(current_file.headlines[3].closed)
    assert.are.same(1, #current_file.headlines[3].dates)
    assert.are.same('2022-06-11 Sat 23:15', current_file.headlines[3].dates[1]:to_string())
  end)

  it('should set provided tags on headline', function()
    local file = helpers.load_file_content({
      '#TITLE: First file',
      '',
      '* TODO Test orgmode :WORK:OFFICE:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '* DONE Some task',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })

    assert.is.True(#api.load() > 1)
    local current_file = api.current()
    assert.are.same(false, current_file.is_archive_file)
    assert.are.same(file, current_file.filename)
    assert.are.same(current_file.category, vim.fn.fnamemodify(file, ':p:t:r'))
    assert.are.same(3, #current_file.headlines)
    assert.are.same('Second level', current_file.headlines[2].title)
    assert.are.same({ 'WORK', 'OFFICE', 'NESTEDTAG' }, current_file.headlines[2].all_tags)

    current_file.headlines[2]:set_tags({ 'PERSONAL', 'HEALTH' })

    assert.are.same({ 'PERSONAL', 'HEALTH' }, api.current().headlines[2].tags)
    assert.are.same({ 'WORK', 'OFFICE', 'PERSONAL', 'HEALTH' }, api.current().headlines[2].all_tags)
    assert.Is.True(vim.fn.getline(5):match(':PERSONAL:HEALTH:$') ~= nil)
  end)

  it('should toggle priority up and down', function()
    helpers.load_file_content({
      '#TITLE: First file',
      '',
      '* TODO Test orgmode :WORK:OFFICE:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '* DONE Some task',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })

    assert.is.True(#api.load() > 1)
    local current_file = api.current()
    local headline = current_file.headlines[2]
    assert.are.same('', headline.priority)
    headline:priority_up()
    assert.are.same('C', api.current().headlines[2].priority)
    assert.Is.True(vim.fn.getline(5):match('%[#C%]') ~= nil)
    headline:priority_up()
    assert.are.same('B', api.current().headlines[2].priority)
    assert.Is.True(vim.fn.getline(5):match('%[#B%]') ~= nil)
    headline:priority_up()
    assert.are.same('A', api.current().headlines[2].priority)
    assert.Is.True(vim.fn.getline(5):match('%[#A%]') ~= nil)
    headline:priority_up()
    assert.are.same('', api.current().headlines[2].priority)
    assert.Is.True(vim.fn.getline(5):match('%[.*%]') == nil)
    headline:priority_down()
    assert.are.same('A', api.current().headlines[2].priority)
    assert.Is.True(vim.fn.getline(5):match('%[#A%]') ~= nil)
    headline:priority_down()
    assert.are.same('B', api.current().headlines[2].priority)
    assert.Is.True(vim.fn.getline(5):match('%[#B%]') ~= nil)
    api.current().headlines[2]:set_priority('C')
    assert.Is.True(vim.fn.getline(5):match('%[#C%]') ~= nil)
    api.current().headlines[2]:set_priority('A')
    assert.Is.True(vim.fn.getline(5):match('%[#A%]') ~= nil)
    api.current().headlines[2]:set_priority('')
    assert.Is.True(vim.fn.getline(5):match('%[.*%]') == nil)
  end)
end)

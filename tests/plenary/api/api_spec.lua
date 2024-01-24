local helpers = require('tests.plenary.ui.helpers')
local api = require('orgmode.api')
local Date = require('orgmode.objects.date')
local OrgId = require('orgmode.org.id')

describe('Api', function()
  it('should parse current file through api', function()
    local file = helpers.load_file_content({
      '#TITLE: First file',
      '',
      '* TODO Test orgmode :WORK:OFFICE:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '* DONE Some task :ARCHIVE:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '  Unrelated date <2022-06-11 Sat 23:15>',
    })

    assert.is.True(#api.load() > 1)
    local current_file = api.current()
    assert.are.same(false, current_file.is_archive_file)
    assert.are.same(file, current_file.filename)
    assert.are.same(current_file.category, vim.fn.fnamemodify(file, ':p:t:r'))
    assert.are.same(3, #current_file.headlines)
    assert.are.same(1, current_file.headlines[1].level)
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
    assert.Is.False(current_file.headlines[1].is_archived)

    assert.are.same(2, current_file.headlines[2].level)
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
    assert.Is.False(current_file.headlines[2].is_archived)
    assert.are.same(current_file.headlines[1], current_file.headlines[2].parent)

    assert.are.same(1, current_file.headlines[3].level)
    assert.are.same('Some task', current_file.headlines[3].title)
    assert.are.same(0, #current_file.headlines[3].headlines)
    assert.are.same({ 'ARCHIVE' }, current_file.headlines[3].all_tags)
    assert.are.same({ 'ARCHIVE' }, current_file.headlines[3].tags)
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
    assert.Is.True(current_file.headlines[3].is_archived)
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

  it('should manipulate deadline date', function()
    helpers.load_file_content({
      '* TODO Test orgmode :WORK:OFFICE:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  SCHEDULED: <2021-07-21 Wed 22:02>',
      '* TODO Some task',
    })
    assert.is.True(#api.load() > 1)
    local current_file = api.current()
    assert.are.same('2021-07-21 Wed 22:02', current_file.headlines[1].deadline:to_string())

    -- Update in place
    api.current().headlines[1]:set_deadline('2022-06-12 Sun 09:30')
    assert.are.same('2022-06-12 Sun 09:30', api.current().headlines[1].deadline:to_string())
    local expect = vim.pesc('  DEADLINE: <2022-06-12 Sun 09:30>')
    assert.Is.True(vim.fn.getline(2):match(expect) ~= nil)

    -- Update second headline with value from Date instance
    local date_instance = Date.from_string('2022-06-15')
    api.current().headlines[2]:set_deadline(date_instance)
    assert.are.same('2022-06-15 Wed', api.current().headlines[2].deadline:to_string())
    expect = vim.pesc('  SCHEDULED: <2021-07-21 Wed 22:02> DEADLINE: <2022-06-15 Wed>')
    assert.Is.True(vim.fn.getline(4):match(expect) ~= nil)

    -- Add to second headline after scheduled
    api.current().headlines[2]:set_deadline('2022-06-12 Sun 11:30')
    assert.are.same('2022-06-12 Sun 11:30', api.current().headlines[2].deadline:to_string())
    expect = vim.pesc('  SCHEDULED: <2021-07-21 Wed 22:02> DEADLINE: <2022-06-12 Sun 11:30>')
    assert.Is.True(vim.fn.getline(4):match(expect) ~= nil)

    -- Add to third headline that doesn't have any plan
    api.current().headlines[3]:set_deadline('2022-06-12 Sun 12:30')
    assert.are.same('2022-06-12 Sun 12:30', api.current().headlines[3].deadline:to_string())
    expect = vim.pesc('  DEADLINE: <2022-06-12 Sun 12:30>')
    assert.Is.True(vim.fn.getline(6):match(expect) ~= nil)

    -- Remove date
    api.current().headlines[1]:set_deadline('')
    assert.Is.Nil(api.current().headlines[1].deadline)
    -- Completely removed the line
    expect = vim.pesc('** TODO Second level :NESTEDTAG:')
    assert.Is.True(vim.fn.getline(2):match(expect) ~= nil)

    -- Remove only scheduled, leave deadline
    api.current().headlines[2]:set_deadline('')
    assert.Is.Nil(api.current().headlines[2].deadline)
    -- Completely removed the line
    expect = vim.pesc('  SCHEDULED: <2021-07-21 Wed 22:02>')
    assert.Is.True(vim.fn.getline(3):match(expect) ~= nil)
  end)

  it('should manipulate schedule date', function()
    helpers.load_file_content({
      '* TODO Test orgmode :WORK:OFFICE:',
      '  SCHEDULED: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '* TODO Some task',
    })
    assert.is.True(#api.load() > 1)
    local current_file = api.current()
    assert.are.same('2021-07-21 Wed 22:02', current_file.headlines[1].scheduled:to_string())

    -- Update in place
    api.current().headlines[1]:set_scheduled('2022-06-12 Sun 09:30')
    assert.are.same('2022-06-12 Sun 09:30', api.current().headlines[1].scheduled:to_string())
    local expect = vim.pesc('  SCHEDULED: <2022-06-12 Sun 09:30>')
    assert.Is.True(vim.fn.getline(2):match(expect) ~= nil)

    -- Add to second headline after sheduled
    api.current().headlines[2]:set_scheduled('2022-06-12 Sun 11:30')
    assert.are.same('2022-06-12 Sun 11:30', api.current().headlines[2].scheduled:to_string())
    expect = vim.pesc('  DEADLINE: <2021-07-21 Wed 22:02> SCHEDULED: <2022-06-12 Sun 11:30>')
    assert.Is.True(vim.fn.getline(4):match(expect) ~= nil)

    -- Update second headline with value from Date instance
    local date_instance = Date.from_string('2022-06-16')
    api.current().headlines[2]:set_scheduled(date_instance)
    assert.are.same('2022-06-16 Thu', api.current().headlines[2].scheduled:to_string())
    expect = vim.pesc('  DEADLINE: <2021-07-21 Wed 22:02> SCHEDULED: <2022-06-16 Thu>')
    assert.Is.True(vim.fn.getline(4):match(expect) ~= nil)

    -- Add to third headline that doesn't have any plan
    api.current().headlines[3]:set_scheduled('2022-06-12 Sun 12:30')
    assert.are.same('2022-06-12 Sun 12:30', api.current().headlines[3].scheduled:to_string())
    expect = vim.pesc('  SCHEDULED: <2022-06-12 Sun 12:30>')
    assert.Is.True(vim.fn.getline(6):match(expect) ~= nil)

    -- Remove date
    api.current().headlines[1]:set_scheduled('')
    assert.Is.Nil(api.current().headlines[1].scheduled)
    -- Completely removed the line
    expect = vim.pesc('** TODO Second level :NESTEDTAG:')
    assert.Is.True(vim.fn.getline(2):match(expect) ~= nil)

    -- Remove only scheduled, leave scheduled
    api.current().headlines[2]:set_scheduled('')
    assert.Is.Nil(api.current().headlines[2].scheduled)
    -- Completely removed the line
    expect = vim.pesc('  DEADLINE: <2021-07-21 Wed 22:02>')
    assert.Is.True(vim.fn.getline(3):match(expect) ~= nil)
  end)

  it('sets the property on the headline', function()
    helpers.load_file_content({
      '* TODO Test orgmode',
      '  SCHEDULED: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '* TODO Some task',
    })

    api.current().headlines[2]:set_property('NAME', 'test')
    assert.are.same({
      '* TODO Test orgmode',
      '  SCHEDULED: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '   :PROPERTIES:',
      '   :NAME: test',
      '   :END:',
      '* TODO Some task',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.are.same(api.current().headlines[2]:get_property('NAME'), 'test')
  end)

  it('sets the id on headline', function()
    helpers.load_file_content({
      '* TODO Test orgmode',
      '  SCHEDULED: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '* TODO Some task',
    })

    local id = api.current().headlines[2]:id_get_or_create()
    assert.is.True(OrgId.is_valid_uuid(id))
    assert.are.same(api.current().headlines[2]:get_property('ID'), id)
    assert.are.same(vim.fn.getline(6), ('   :ID: %s'):format(id))
  end)
end)

local helpers = require('tests.plenary.helpers')
local api = require('orgmode.api')
local Date = require('orgmode.objects.date')
local OrgId = require('orgmode.org.id')
local orgmode = require('orgmode')

describe('Api', function()
  ---@return OrgApiFile
  local cur_file = function()
    -- Wait for 1ms to ensure that the file is reloaded
    vim.wait(1)
    return api.current()
  end
  it('should parse current file through api', function()
    local file = helpers.create_file({
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
    local current_file = cur_file()
    assert.are.same(false, current_file.is_archive_file)
    assert.are.same(file.filename, current_file.filename)
    assert.are.same(current_file.category, vim.fn.fnamemodify(file.filename, ':p:t:r'))
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
    assert.is.Nil(current_file.headlines[1].scheduled)
    assert.is.Nil(current_file.headlines[1].closed)
    assert.are.same({}, current_file.headlines[1].dates)
    assert.is.False(current_file.headlines[1].is_archived)

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
    assert.is.False(current_file.headlines[2].is_archived)
    assert.are.same(current_file.headlines[1], current_file.headlines[2].parent)

    assert.are.same(1, current_file.headlines[3].level)
    assert.are.same('Some task', current_file.headlines[3].title)
    assert.are.same(0, #current_file.headlines[3].headlines)
    assert.are.same({ 'ARCHIVE' }, current_file.headlines[3].all_tags)
    assert.are.same({ 'ARCHIVE' }, current_file.headlines[3].tags)
    assert.are.same('DONE', current_file.headlines[3].todo_value)
    assert.are.same('DONE', current_file.headlines[3].todo_type)
    assert.are.same(7, current_file.headlines[3].position.start_line)
    assert.are.same(9, current_file.headlines[3].position.end_line)
    assert.is.Nil(current_file.headlines[3].parent)
    assert.are.same('2021-07-21 Wed 22:02', current_file.headlines[3].deadline:to_string())
    assert.is.Nil(current_file.headlines[3].scheduled)
    assert.is.Nil(current_file.headlines[3].closed)
    assert.is.True(current_file.headlines[3].is_archived)
    assert.are.same(1, #current_file.headlines[3].dates)
    assert.are.same('2022-06-11 Sat 23:15', current_file.headlines[3].dates[1]:to_string())
  end)

  it('should set provided tags on headline', function()
    local file = helpers.create_file({
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
    local current_file = cur_file()
    assert.are.same(false, current_file.is_archive_file)
    assert.are.same(file.filename, current_file.filename)
    assert.are.same(current_file.category, vim.fn.fnamemodify(file.filename, ':p:t:r'))
    assert.are.same(3, #current_file.headlines)
    assert.are.same('Second level', current_file.headlines[2].title)
    assert.are.same({ 'WORK', 'OFFICE', 'NESTEDTAG' }, current_file.headlines[2].all_tags)

    current_file.headlines[2]:set_tags({ 'PERSONAL', 'HEALTH' }):wait()

    assert.are.same({ 'PERSONAL', 'HEALTH' }, cur_file().headlines[2].tags)
    assert.are.same({ 'WORK', 'OFFICE', 'PERSONAL', 'HEALTH' }, cur_file().headlines[2].all_tags)
    assert.is.True(vim.fn.getline(5):match(':PERSONAL:HEALTH:$') ~= nil)
  end)

  it('should toggle priority up and down', function()
    helpers.create_file({
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
    local current_file = cur_file()
    local headline = current_file.headlines[2]
    assert.are.same('', headline.priority)
    headline:priority_up():wait()
    assert.are.same('C', cur_file().headlines[2].priority)
    assert.is.True(vim.fn.getline(5):match('%[#C%]') ~= nil)
    headline:priority_up():wait()
    assert.are.same('B', cur_file().headlines[2].priority)
    assert.is.True(vim.fn.getline(5):match('%[#B%]') ~= nil)
    headline:priority_up():wait()
    assert.are.same('A', cur_file().headlines[2].priority)
    assert.is.True(vim.fn.getline(5):match('%[#A%]') ~= nil)
    headline:priority_up():wait()
    assert.are.same('', cur_file().headlines[2].priority)
    assert.is.True(vim.fn.getline(5):match('%[.*%]') == nil)
    headline:priority_down():wait()
    assert.are.same('A', cur_file().headlines[2].priority)
    assert.is.True(vim.fn.getline(5):match('%[#A%]') ~= nil)
    headline:priority_down():wait()
    assert.are.same('B', cur_file().headlines[2].priority)
    assert.is.True(vim.fn.getline(5):match('%[#B%]') ~= nil)
    cur_file().headlines[2]:set_priority('C'):wait()
    assert.is.True(vim.fn.getline(5):match('%[#C%]') ~= nil)
    cur_file().headlines[2]:set_priority('A'):wait()
    assert.is.True(vim.fn.getline(5):match('%[#A%]') ~= nil)
    cur_file().headlines[2]:set_priority(''):wait()
    assert.is.True(vim.fn.getline(5):match('%[.*%]') == nil)
  end)

  it('should manipulate deadline date', function()
    helpers.create_file({
      '* TODO Test orgmode :WORK:OFFICE:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  SCHEDULED: <2021-07-21 Wed 22:02>',
      '* TODO Some task',
    })
    assert.is.True(#api.load() > 1)
    local current_file = cur_file()
    assert.are.same('2021-07-21 Wed 22:02', current_file.headlines[1].deadline:to_string())

    -- Update in place
    cur_file().headlines[1]:set_deadline('2022-06-12 Sun 09:30'):wait()
    assert.are.same('2022-06-12 Sun 09:30', cur_file().headlines[1].deadline:to_string())
    local expect = vim.pesc('  DEADLINE: <2022-06-12 Sun 09:30>')
    assert.is.True(vim.fn.getline(2):match(expect) ~= nil)

    -- Update second headline with value from Date instance
    local date_instance = Date.from_string('2022-06-15')
    cur_file().headlines[2]:set_deadline(date_instance):wait()
    assert.are.same('2022-06-15 Wed', cur_file().headlines[2].deadline:to_string())
    expect = vim.pesc('  SCHEDULED: <2021-07-21 Wed 22:02> DEADLINE: <2022-06-15 Wed>')
    assert.is.True(vim.fn.getline(4):match(expect) ~= nil)

    -- Add to second headline after scheduled
    cur_file().headlines[2]:set_deadline('2022-06-12 Sun 11:30'):wait()
    assert.are.same('2022-06-12 Sun 11:30', cur_file().headlines[2].deadline:to_string())
    expect = vim.pesc('  SCHEDULED: <2021-07-21 Wed 22:02> DEADLINE: <2022-06-12 Sun 11:30>')
    assert.is.True(vim.fn.getline(4):match(expect) ~= nil)

    -- Add to third headline that doesn't have any plan
    cur_file().headlines[3]:set_deadline('2022-06-12 Sun 12:30'):wait()
    assert.are.same('2022-06-12 Sun 12:30', cur_file().headlines[3].deadline:to_string())
    expect = vim.pesc('  DEADLINE: <2022-06-12 Sun 12:30>')
    assert.is.True(vim.fn.getline(6):match(expect) ~= nil)

    -- Remove date
    cur_file().headlines[1]:set_deadline(''):wait()
    assert.is.Nil(cur_file().headlines[1].deadline)
    -- Completely removed the line
    expect = vim.pesc('** TODO Second level :NESTEDTAG:')
    assert.is.True(vim.fn.getline(2):match(expect) ~= nil)

    -- Remove only scheduled, leave deadline
    cur_file().headlines[2]:set_deadline(''):wait()
    assert.is.Nil(cur_file().headlines[2].deadline)
    -- Completely removed the line
    expect = vim.pesc('  SCHEDULED: <2021-07-21 Wed 22:02>')
    assert.is.True(vim.fn.getline(3):match(expect) ~= nil)
  end)

  it('should manipulate schedule date', function()
    helpers.create_file({
      '* TODO Test orgmode :WORK:OFFICE:',
      '  SCHEDULED: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '* TODO Some task',
    })
    assert.is.True(#api.load() > 1)
    local current_file = cur_file()
    assert.are.same('2021-07-21 Wed 22:02', current_file.headlines[1].scheduled:to_string())

    -- Update in place
    cur_file().headlines[1]:set_scheduled('2022-06-12 Sun 09:30'):wait()
    assert.are.same('2022-06-12 Sun 09:30', cur_file().headlines[1].scheduled:to_string())
    local expect = vim.pesc('  SCHEDULED: <2022-06-12 Sun 09:30>')
    assert.is.True(vim.fn.getline(2):match(expect) ~= nil)

    -- Add to second headline after sheduled
    cur_file().headlines[2]:set_scheduled('2022-06-12 Sun 11:30'):wait()
    assert.are.same('2022-06-12 Sun 11:30', cur_file().headlines[2].scheduled:to_string())
    expect = vim.pesc('  DEADLINE: <2021-07-21 Wed 22:02> SCHEDULED: <2022-06-12 Sun 11:30>')
    assert.is.True(vim.fn.getline(4):match(expect) ~= nil)

    -- Update second headline with value from Date instance
    local date_instance = Date.from_string('2022-06-16')
    cur_file().headlines[2]:set_scheduled(date_instance):wait()
    assert.are.same('2022-06-16 Thu', cur_file().headlines[2].scheduled:to_string())
    expect = vim.pesc('  DEADLINE: <2021-07-21 Wed 22:02> SCHEDULED: <2022-06-16 Thu>')
    assert.is.True(vim.fn.getline(4):match(expect) ~= nil)

    -- Add to third headline that doesn't have any plan
    cur_file().headlines[3]:set_scheduled('2022-06-12 Sun 12:30'):wait()
    assert.are.same('2022-06-12 Sun 12:30', cur_file().headlines[3].scheduled:to_string())
    expect = vim.pesc('  SCHEDULED: <2022-06-12 Sun 12:30>')
    assert.is.True(vim.fn.getline(6):match(expect) ~= nil)

    -- Remove date
    cur_file().headlines[1]:set_scheduled(''):wait()
    assert.is.Nil(cur_file().headlines[1].scheduled)
    -- Completely removed the line
    expect = vim.pesc('** TODO Second level :NESTEDTAG:')
    assert.is.True(vim.fn.getline(2):match(expect) ~= nil)

    -- Remove only scheduled, leave scheduled
    cur_file().headlines[2]:set_scheduled(''):wait()
    assert.is.Nil(cur_file().headlines[2].scheduled)
    -- Completely removed the line
    expect = vim.pesc('  DEADLINE: <2021-07-21 Wed 22:02>')
    assert.is.True(vim.fn.getline(3):match(expect) ~= nil)
  end)

  it('sets the property on the headline', function()
    helpers.create_file({
      '* TODO Test orgmode',
      '  SCHEDULED: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '* TODO Some task',
    })

    cur_file().headlines[2]:set_property('NAME', 'test'):wait()
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
    assert.are.same(cur_file().headlines[2]:get_property('NAME'), 'test')
  end)

  it('sets the id on headline', function()
    helpers.create_file({
      '* TODO Test orgmode',
      '  SCHEDULED: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '* TODO Some task',
    })

    local id = cur_file().headlines[2]:id_get_or_create()
    assert.is.True(OrgId.is_valid_uuid(id))
    assert.are.same(cur_file().headlines[2]:get_property('ID'), id)
    assert.are.same(vim.fn.getline(6), ('   :ID: %s'):format(id))
  end)

  it('should get closest headline', function()
    helpers.create_agenda_file({
      '* TODO Test orgmode',
      '  SCHEDULED: <2021-07-21 Wed 22:02>',
      '** TODO Second level :NESTEDTAG:',
      '   DEADLINE: <2021-07-21 Wed 22:02>',
      '* TODO Some task',
      '  The content',
      '* TODO Some other task',
    })

    vim.fn.cursor({ 4, 1 })
    local closest_headline = api.current():get_closest_headline()
    assert(closest_headline)
    assert.are.same('Second level', closest_headline.title)

    local headline_at_cursor = api.current():get_closest_headline({ 6, 1 })
    assert(headline_at_cursor)
    assert.are.same('Some task', headline_at_cursor.title)

    helpers.create_agenda_file({
      'This file does not have headline',
      'Just some content',
    })

    vim.fn.cursor({ 2, 1 })
    closest_headline = api.current():get_closest_headline()
    assert.is.Nil(closest_headline)
  end)

  describe('Refile', function()
    describe('from org file', function()
      it('should refile a headline to another file', function()
        local destination_file = helpers.create_agenda_file({
          '* TODO Test orgmode',
          '  SCHEDULED: <2021-07-21 Wed 22:02>',
          '** TODO Refiled here',
          '   DEADLINE: <2021-07-21 Wed 22:02>',
          '* TODO Some task',
        })

        local source_file = helpers.create_agenda_file({
          '* TODO Test orgmode',
          '  SCHEDULED: <2021-07-21 Wed 22:02>',
          '** TODO Second level :NESTEDTAG:',
          '   DEADLINE: <2021-07-21 Wed 22:02>',
          '* TODO Some task',
        })

        api.refile({
          source = api.current().headlines[2],
          destination = api.load(destination_file.filename),
        })

        assert.are.same(vim.api.nvim_buf_get_name(0), source_file.filename)
        vim.cmd('e' .. destination_file.filename)

        assert.are.same({
          '* TODO Test orgmode',
          '  SCHEDULED: <2021-07-21 Wed 22:02>',
          '** TODO Refiled here',
          '   DEADLINE: <2021-07-21 Wed 22:02>',
          '* TODO Some task',
          '* TODO Second level :NESTEDTAG:',
          '  DEADLINE: <2021-07-21 Wed 22:02>',
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)

      it('should refile a headline to another headline', function()
        local destination_file = helpers.create_agenda_file({
          '* TODO Test orgmode',
          '  SCHEDULED: <2021-07-21 Wed 22:02>',
          '** TODO Refiled here',
          '   DEADLINE: <2021-07-21 Wed 22:02>',
          '* TODO Some task',
        })

        local source_file = helpers.create_agenda_file({
          '* TODO Test orgmode',
          '  SCHEDULED: <2021-07-21 Wed 22:02>',
          '** TODO Second level :NESTEDTAG:',
          '   DEADLINE: <2021-07-21 Wed 22:02>',
          '* TODO Some task',
        })

        assert.are.same(vim.api.nvim_buf_get_name(0), source_file.filename)

        api.refile({
          source = api.current().headlines[2],
          destination = api.load(destination_file.filename).headlines[2],
        })

        vim.cmd('e' .. destination_file.filename)

        assert.are.same({
          '* TODO Test orgmode',
          '  SCHEDULED: <2021-07-21 Wed 22:02>',
          '** TODO Refiled here',
          '   DEADLINE: <2021-07-21 Wed 22:02>',
          '*** TODO Second level :NESTEDTAG:',
          '    DEADLINE: <2021-07-21 Wed 22:02>',
          '* TODO Some task',
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)
    end)

    describe('from org capture buffer', function()
      it('should refile a headline to another file', function()
        local destination_file = helpers.create_agenda_file({
          '* TODO Test orgmode',
          '  SCHEDULED: <2021-07-21 Wed 22:02>',
          '** TODO Refiled here',
          '   DEADLINE: <2021-07-21 Wed 22:02>',
          '* TODO Some task',
        })

        orgmode.capture:open_template_by_shortcut('t')
        local source_file = vim.api.nvim_buf_get_name(0)
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          '* TODO Second level :NESTEDTAG:',
          '  DEADLINE: <2021-07-21 Wed 22:02>',
        })

        api.refile({
          source = api.current().headlines[1],
          destination = api.load(destination_file.filename),
        })

        assert.are.Not.same(vim.api.nvim_buf_get_name(0), source_file)

        vim.cmd('e' .. destination_file.filename)

        assert.are.same({
          '* TODO Test orgmode',
          '  SCHEDULED: <2021-07-21 Wed 22:02>',
          '** TODO Refiled here',
          '   DEADLINE: <2021-07-21 Wed 22:02>',
          '* TODO Some task',
          '* TODO Second level :NESTEDTAG:',
          '  DEADLINE: <2021-07-21 Wed 22:02>',
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)

      it('should refile a headline to another headline', function()
        local destination_file = helpers.create_agenda_file({
          '* TODO Test orgmode',
          '  SCHEDULED: <2021-07-21 Wed 22:02>',
          '** TODO Refiled here',
          '   DEADLINE: <2021-07-21 Wed 22:02>',
          '* TODO Some task',
        })

        orgmode.capture:open_template_by_shortcut('t')
        local source_file = vim.api.nvim_buf_get_name(0)
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          '* TODO Second level :NESTEDTAG:',
          '  DEADLINE: <2021-07-21 Wed 22:02>',
        })

        api.refile({
          source = api.current().headlines[1],
          destination = api.load(destination_file.filename).headlines[2],
        })

        assert.are.Not.same(vim.api.nvim_buf_get_name(0), source_file)

        vim.cmd('e' .. destination_file.filename)

        assert.are.same({
          '* TODO Test orgmode',
          '  SCHEDULED: <2021-07-21 Wed 22:02>',
          '** TODO Refiled here',
          '   DEADLINE: <2021-07-21 Wed 22:02>',
          '*** TODO Second level :NESTEDTAG:',
          '    DEADLINE: <2021-07-21 Wed 22:02>',
          '* TODO Some task',
        }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      end)
    end)
  end)
end)

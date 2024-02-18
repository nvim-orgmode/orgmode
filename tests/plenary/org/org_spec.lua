local helpers = require('tests.plenary.helpers')
local Date = require('orgmode.objects.date')
local org = require('orgmode')

describe('Org file', function()
  it('should properly add new properties to a section', function()
    helpers.create_file({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '* TODO Another todo',
    })

    local headline = org.files:get_closest_headline({ 1, 0 })
    assert.are.same('Test orgmode', headline:get_title())
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
    helpers.create_file({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '  :PROPERTIES:',
      '  :CATEGORY: Testing',
      '  :END:',
      '* TODO Another todo',
    })
    local headline = org.files:get_closest_headline({ 1, 0 })
    assert.are.same('Test orgmode', headline:get_title())
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
    helpers.create_file({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00 +1w>',
      '  :PROPERTIES:',
      '  :CATEGORY: Testing',
      '  :CUSTOM_ID: 1',
      '  :END:',
      '* TODO Another todo',
    })
    local headline = org.files:get_closest_headline({ 1, 0 })
    assert.are.same('Test orgmode', headline:get_title())
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
    local now = Date.now()
    helpers.create_file({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      '* TODO Another todo',
    })

    local headline = org.files:get_closest_headline({ 1, 0 })
    headline:set_closed_date()

    assert.are.same({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00> CLOSED: ' .. now:to_wrapped_string(false),
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))

    headline:set_closed_date()
    -- unchanged
    assert.are.same({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00> CLOSED: ' .. now:to_wrapped_string(false),
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))
  end)

  it('should remove closed date from section if it exists', function()
    local now = Date.now()
    helpers.create_file({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00> CLOSED: ' .. now:to_wrapped_string(false),
      '* TODO Another todo',
    })
    local headline = org.files:get_closest_headline({ 1, 0 })
    headline:remove_closed_date()

    assert.are.same({
      '* TODO Test orgmode :WORK:',
      'DEADLINE: <2021-05-10 11:00>',
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))

    helpers.create_file({
      '* TODO Test orgmode only closed :WORK:',
      'CLOSED: ' .. now:to_wrapped_string(false),
      '* TODO Another todo',
    })

    local headline = org.files:get_closest_headline({ 1, 0 })
    assert.are.same('Test orgmode only closed', headline:get_title())
    headline:remove_closed_date()
    assert.are.same({
      '* TODO Test orgmode only closed :WORK:',
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))
  end)

  it('should add and update deadline date', function()
    local deadline_date = Date.from_string('2021-08-18 Wed')
    helpers.create_file({
      '* TODO Test orgmode :WORK:',
      '* TODO Another todo',
    })
    local headline = org.files:get_closest_headline({ 1, 0 })
    headline:set_deadline_date(deadline_date)

    assert.are.same({
      '* TODO Test orgmode :WORK:',
      '  DEADLINE: <2021-08-18 Wed>',
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))

    headline:set_deadline_date(deadline_date:add({ day = 2 }))

    assert.are.same({
      '* TODO Test orgmode :WORK:',
      '  DEADLINE: <2021-08-20 Fri>',
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))
  end)

  it('should add, update and remove scheduled date', function()
    local scheduled_date = Date.from_string('2021-08-18 Wed')
    helpers.create_file({
      '* TODO Test orgmode :WORK:',
      '* TODO Another todo',
    })
    local headline = org.files:get_closest_headline({ 1, 0 })
    headline:set_scheduled_date(scheduled_date)

    assert.are.same({
      '* TODO Test orgmode :WORK:',
      '  SCHEDULED: <2021-08-18 Wed>',
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))

    helpers.create_file({
      '* TODO Test orgmode :WORK:',
      '  DEADLINE: <2021-08-18 Wed>',
      '* TODO Another todo',
    })

    headline = org.files:get_closest_headline({ 1, 0 })
    headline:set_scheduled_date(scheduled_date)

    assert.are.same({
      '* TODO Test orgmode :WORK:',
      '  DEADLINE: <2021-08-18 Wed> SCHEDULED: <2021-08-18 Wed>',
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))

    headline:set_scheduled_date(scheduled_date:add({ day = 4 }))

    assert.are.same({
      '* TODO Test orgmode :WORK:',
      '  DEADLINE: <2021-08-18 Wed> SCHEDULED: <2021-08-22 Sun>',
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))

    headline:remove_scheduled_date()

    assert.are.same({
      '* TODO Test orgmode :WORK:',
      '  DEADLINE: <2021-08-18 Wed>',
      '* TODO Another todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))
  end)
end)

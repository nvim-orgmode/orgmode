local org = require('orgmode')
local Range = require('orgmode.files.elements.range')
local Date = require('orgmode.objects.date')
local Notifications = require('orgmode.notifications')
local last_filename = nil
local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')

describe('Notifications', function()
  it('should find headlines for notification', function()
    local lines = {
      '* TODO I am the deadline task :OFFICE:',
      '  DEADLINE: <2021-07-12 Mon 12:30>',
      '* TODO I am the scheduled task',
      '  SCHEDULED: <2021-07-12 Mon 12:30>',
      '* TODO I am the deadline task for evening',
      '  DEADLINE: <2021-07-12 Mon 19:30>',
      '* TODO I am the scheduled task for evening',
      '  SCHEDULED: <2021-07-12 Mon 19:30>',
    }
    local orgfile = helpers.create_agenda_file(lines)
    local notifications = Notifications:new({
      files = org.files,
    })
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-11 Sun 12:30')))
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-12 Mon 10:30')))
    local first_heading = orgfile:get_headlines()[1]
    local second_heading = orgfile:get_headlines()[2]
    assert.are.same({
      {
        file = orgfile.filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(orgfile.filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = { 'OFFICE' },
        range = Range:new({ start_line = 1, end_line = 2, end_col = 0 }),
        original_time = first_heading:get_all_dates()[1],
        time = first_heading:get_all_dates()[1],
        type = 'DEADLINE',
        minutes = 10,
        humanized_duration = 'in 10 min',
        reminder_type = 'time',
      },
      {
        file = orgfile.filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(orgfile.filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        range = Range:new({ start_line = 3, end_line = 4, end_col = 0 }),
        original_time = second_heading:get_all_dates()[1],
        time = second_heading:get_all_dates()[1],
        minutes = 10,
        humanized_duration = 'in 10 min',
        type = 'SCHEDULED',
        reminder_type = 'time',
      },
    }, notifications:get_tasks(Date.from_string('2021-07-12 Mon 12:20')))
  end)

  it('should find repeatable and warning deadlines for notification', function()
    local lines = {
      '* TODO I am the deadline task :OFFICE:',
      '  DEADLINE: <2021-07-07 Wed 12:30 +1w>',
      '* TODO I am the scheduled task',
      '  SCHEDULED: <2021-07-14 Wed 12:30>',
      '* TODO I am the deadline task for evening',
      '  DEADLINE: <2021-07-14 Wed 19:30 -7h>',
      '* TODO I am the scheduled task for evening',
      '  SCHEDULED: <2021-07-14 Wed 19:30>',
    }
    local orgfile = helpers.create_agenda_file(lines, {
      notifications = {
        reminder_time = { 10, 0 },
        deadline_warning_reminder_time = { 10, 5, 0, -5 },
        repeater_reminder_time = { 10, 5, 0 },
      },
    })
    local notifications = Notifications:new({
      files = org.files,
    })
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-13 Sun 12:30')))
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-14 Mon 10:30')))
    local first_heading = orgfile:get_headlines()[1]
    local second_heading = orgfile:get_headlines()[2]
    local third_heading = orgfile:get_headlines()[3]

    local time = Date.from_string('2021-07-14 Mon 12:20')
    local tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = orgfile.filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(orgfile.filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = { 'OFFICE' },
        range = Range:new({ start_line = 1, end_line = 2, end_col = 0 }),
        original_time = first_heading:get_all_dates()[1],
        time = first_heading:get_all_dates()[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 10,
        humanized_duration = 'in 10 min',
      },
      {
        file = orgfile.filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(orgfile.filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        time = second_heading:get_all_dates()[1],
        range = Range:new({ start_line = 3, end_line = 4, end_col = 0 }),
        original_time = second_heading:get_all_dates()[1],
        type = 'SCHEDULED',
        reminder_type = 'time',
        minutes = 10,
        humanized_duration = 'in 10 min',
      },
      {
        file = orgfile.filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(orgfile.filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6, end_col = 0 }),
        original_time = third_heading:get_all_dates()[1],
        time = third_heading:get_all_dates()[1]:without_adjustments(),
        minutes = 430,
        humanized_duration = 'in 7 hr and 10 min',
        type = 'DEADLINE',
        reminder_type = 'warning',
      },
    }, tasks)

    time = Date.from_string('2021-07-14 Mon 12:25')
    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = orgfile.filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(orgfile.filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = { 'OFFICE' },
        range = Range:new({ start_line = 1, end_line = 2, end_col = 0 }),
        original_time = first_heading:get_all_dates()[1],
        time = first_heading:get_all_dates()[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 5,
        humanized_duration = 'in 5 min',
      },
      {
        file = orgfile.filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(orgfile.filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6, end_col = 0 }),
        original_time = third_heading:get_all_dates()[1],
        time = third_heading:get_all_dates()[1]:without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'warning',
        minutes = 425,
        humanized_duration = 'in 7 hr and 5 min',
      },
    }, tasks)

    time = Date.from_string('2021-07-14 Mon 12:30')
    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = orgfile.filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(orgfile.filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = { 'OFFICE' },
        range = Range:new({ start_line = 1, end_line = 2, end_col = 0 }),
        original_time = first_heading:get_all_dates()[1],
        time = first_heading:get_all_dates()[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 0,
        humanized_duration = 'Now',
      },
      {
        file = orgfile.filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(orgfile.filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        range = Range:new({ start_line = 3, end_line = 4, end_col = 0 }),
        original_time = second_heading:get_all_dates()[1],
        time = second_heading:get_all_dates()[1],
        type = 'SCHEDULED',
        reminder_type = 'time',
        minutes = 0,
        humanized_duration = 'Now',
      },
      {
        file = orgfile.filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(orgfile.filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6, end_col = 0 }),
        original_time = third_heading:get_all_dates()[1],
        time = third_heading:get_all_dates()[1]:without_adjustments(),
        type = 'DEADLINE',
        minutes = 420,
        humanized_duration = 'in 7 hr',
        reminder_type = 'warning',
      },
    }, tasks)

    time = Date.from_string('2021-07-14 Mon 12:35')
    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = orgfile.filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(orgfile.filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6, end_col = 0 }),
        original_time = third_heading:get_all_dates()[1],
        time = third_heading:get_all_dates()[1]:without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'warning',
        minutes = 415,
        humanized_duration = 'in 6 hr and 55 min',
      },
    }, tasks)
    last_filename = orgfile.filename
  end)

  it('should allow disabling specific reminder times', function()
    ---@diagnostic disable-next-line: param-type-mismatch
    local orgfile = org.files:get(last_filename)
    assert(orgfile)
    local notifications = Notifications:new({
      files = org.files,
    })
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-13 Sun 12:30')))
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-14 Mon 10:30')))
    local first_heading = orgfile:get_headlines()[1]
    local second_heading = orgfile:get_headlines()[2]
    local third_heading = orgfile:get_headlines()[3]

    local time = Date.from_string('2021-07-14 Mon 12:20')
    local tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = { 'OFFICE' },
        range = Range:new({ start_line = 1, end_line = 2, end_col = 0 }),
        original_time = first_heading:get_all_dates()[1],
        time = first_heading:get_all_dates()[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 10,
        humanized_duration = 'in 10 min',
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        range = Range:new({ start_line = 3, end_line = 4, end_col = 0 }),
        original_time = second_heading:get_all_dates()[1],
        time = second_heading:get_all_dates()[1],
        type = 'SCHEDULED',
        reminder_type = 'time',
        minutes = 10,
        humanized_duration = 'in 10 min',
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6, end_col = 0 }),
        original_time = third_heading:get_all_dates()[1],
        time = third_heading:get_all_dates()[1]:without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'warning',
        minutes = 430,
        humanized_duration = 'in 7 hr and 10 min',
      },
    }, tasks)

    config:extend({
      notifications = {
        reminder_time = false,
        deadline_warning_reminder_time = false,
        repeater_reminder_time = { 10, 5, 0 },
      },
    })

    time = Date.from_string('2021-07-14 Mon 12:20')
    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = { 'OFFICE' },
        range = Range:new({ start_line = 1, end_line = 2, end_col = 0 }),
        original_time = first_heading:get_all_dates()[1],
        time = first_heading:get_all_dates()[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 10,
        humanized_duration = 'in 10 min',
      },
    }, tasks)

    config:extend({
      notifications = {
        reminder_time = 10,
        deadline_warning_reminder_time = { 10, 5, 0 },
        repeater_reminder_time = { 10, 5, 0 },
      },
    })

    time = Date.from_string('2021-07-14 Mon 12:20')
    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = { 'OFFICE' },
        range = Range:new({ start_line = 1, end_line = 2, end_col = 0 }),
        original_time = first_heading:get_all_dates()[1],
        time = first_heading:get_all_dates()[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 10,
        humanized_duration = 'in 10 min',
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        range = Range:new({ start_line = 3, end_line = 4, end_col = 0 }),
        original_time = second_heading:get_all_dates()[1],
        time = second_heading:get_all_dates()[1],
        type = 'SCHEDULED',
        reminder_type = 'time',
        minutes = 10,
        humanized_duration = 'in 10 min',
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6, end_col = 0 }),
        original_time = third_heading:get_all_dates()[1],
        time = third_heading:get_all_dates()[1]:without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'warning',
        minutes = 430,
        humanized_duration = 'in 7 hr and 10 min',
      },
    }, tasks)
    last_filename = orgfile.filename
  end)

  it('should allow disabling specific reminder types', function()
    ---@diagnostic disable-next-line: param-type-mismatch
    local orgfile = org.files:get(last_filename)
    assert(orgfile)
    local notifications = Notifications:new({
      files = org.files,
    })
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-13 Sun 12:30')))
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-14 Mon 10:30')))
    local first_heading = orgfile:get_headlines()[1]
    local second_heading = orgfile:get_headlines()[2]
    local third_heading = orgfile:get_headlines()[3]

    local time = Date.from_string('2021-07-14 Mon 12:20')
    local tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = { 'OFFICE' },
        range = Range:new({ start_line = 1, end_line = 2, end_col = 0 }),
        original_time = first_heading:get_all_dates()[1],
        time = first_heading:get_all_dates()[1]:apply_repeater_until(time):without_adjustments(),
        minutes = 10,
        humanized_duration = 'in 10 min',
        type = 'DEADLINE',
        reminder_type = 'repeater',
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        range = Range:new({ start_line = 3, end_line = 4, end_col = 0 }),
        original_time = second_heading:get_all_dates()[1],
        time = second_heading:get_all_dates()[1],
        type = 'SCHEDULED',
        minutes = 10,
        humanized_duration = 'in 10 min',
        reminder_type = 'time',
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6, end_col = 0 }),
        original_time = third_heading:get_all_dates()[1],
        time = third_heading:get_all_dates()[1]:without_adjustments(),
        type = 'DEADLINE',
        minutes = 430,
        humanized_duration = 'in 7 hr and 10 min',
        reminder_type = 'warning',
      },
    }, tasks)

    config:extend({
      notifications = {
        deadline_reminder = false,
      },
    })

    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        range = Range:new({ start_line = 3, end_line = 4, end_col = 0 }),
        original_time = second_heading:get_all_dates()[1],
        time = second_heading:get_all_dates()[1],
        type = 'SCHEDULED',
        reminder_type = 'time',
        minutes = 10,
        humanized_duration = 'in 10 min',
      },
    }, tasks)

    config:extend({
      notifications = {
        scheduled_reminder = false,
        deadline_reminder = true,
      },
    })

    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = { 'OFFICE' },
        range = Range:new({ start_line = 1, end_line = 2, end_col = 0 }),
        original_time = first_heading:get_all_dates()[1],
        time = first_heading:get_all_dates()[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 10,
        humanized_duration = 'in 10 min',
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = vim.fn.fnamemodify(last_filename, ':t:r'),
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6, end_col = 0 }),
        original_time = third_heading:get_all_dates()[1],
        time = third_heading:get_all_dates()[1]:without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'warning',
        minutes = 430,
        humanized_duration = 'in 7 hr and 10 min',
      },
    }, tasks)
  end)
end)

local parser = require('orgmode.parser')
local Files = require('orgmode.parser.files')
local Range = require('orgmode.parser.range')
local Date = require('orgmode.objects.date')
local Notifications = require('orgmode.notifications')
local config = require('orgmode.config')
local last_filename = nil

describe('Notifications', function()
  it('should find headlines for notification', function()
    local filename = vim.fn.tempname()
    last_filename = filename
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
    local orgfile = parser.parse(lines, 'work', filename)
    Files.files[filename] = orgfile
    local notifications = Notifications:new()
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-11 Sun 12:30')))
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-12 Mon 10:30')))
    local first_heading = orgfile:get_item(1)
    local second_heading = orgfile:get_item(3)
    assert.are.same({
      {
        file = filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = {'OFFICE'},
        range = Range:new({ start_line = 1, end_line = 2 }),
        original_time = first_heading.dates[1],
        time = first_heading.dates[1],
        type = 'DEADLINE',
        minutes = 10,
        reminder_type = 'time',
      },
      {
        file = filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        range = Range:new({ start_line = 3, end_line = 4 }),
        original_time = second_heading.dates[1],
        time = second_heading.dates[1],
        minutes = 10,
        type = 'SCHEDULED',
        reminder_type = 'time',
      },
    }, notifications:get_tasks(Date.from_string('2021-07-12 Mon 12:20')))
  end)

  it('should find repeatable and warning deadlines for notification', function()
    config:extend({
      notifications = {
        reminder_time = {10, 0},
        deadline_warning_reminder_time = {10, 5, 0, -5},
        repeater_reminder_time = {10, 5, 0},
      }
    })

    local filename = vim.fn.tempname()
    last_filename = filename
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
    local orgfile = parser.parse(lines, 'work', filename)
    Files.files[filename] = orgfile
    local notifications = Notifications:new()
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-13 Sun 12:30')))
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-14 Mon 10:30')))
    local first_heading = orgfile:get_item(1)
    local second_heading = orgfile:get_item(3)
    local third_heading = orgfile:get_item(5)

    local time = Date.from_string('2021-07-14 Mon 12:20')
    local tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = {'OFFICE'},
        range = Range:new({ start_line = 1, end_line = 2 }),
        original_time = first_heading.dates[1],
        time = first_heading.dates[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 10,
      },
      {
        file = filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        time = second_heading.dates[1],
        range = Range:new({ start_line = 3, end_line = 4 }),
        original_time = second_heading.dates[1],
        type = 'SCHEDULED',
        reminder_type = 'time',
        minutes = 10,
      },
      {
        file = filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6 }),
        original_time = third_heading.dates[1],
        time = third_heading.dates[1]:with_negative_adjustment():without_adjustments(),
        minutes = 10,
        type = 'DEADLINE',
        reminder_type = 'warning',
      },
    }, tasks)

    time = Date.from_string('2021-07-14 Mon 12:25')
    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = {'OFFICE'},
        range = Range:new({ start_line = 1, end_line = 2 }),
        original_time = first_heading.dates[1],
        time = first_heading.dates[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 5,
      },
      {
        file = filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6 }),
        original_time = third_heading.dates[1],
        time = third_heading.dates[1]:with_negative_adjustment():without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'warning',
        minutes = 5,
      },
    }, tasks)

    time = Date.from_string('2021-07-14 Mon 12:30')
    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = {'OFFICE'},
        range = Range:new({ start_line = 1, end_line = 2 }),
        original_time = first_heading.dates[1],
        time = first_heading.dates[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 0
      },
      {
        file = filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        range = Range:new({ start_line = 3, end_line = 4 }),
        original_time = second_heading.dates[1],
        time = second_heading.dates[1],
        type = 'SCHEDULED',
        reminder_type = 'time',
        minutes = 0,
      },
      {
        file = filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6 }),
        original_time = third_heading.dates[1],
        time = third_heading.dates[1]:with_negative_adjustment():without_adjustments(),
        type = 'DEADLINE',
        minutes = 0,
        reminder_type = 'warning',
      },
    }, tasks)

    time = Date.from_string('2021-07-14 Mon 12:35')
    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6 }),
        original_time = third_heading.dates[1],
        time = third_heading.dates[1]:with_negative_adjustment():without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'warning',
        minutes = -5,
      },
    }, tasks)
  end)

  it('should allow disabling specific reminder times', function()
    local orgfile = Files.get(last_filename)
    local notifications = Notifications:new()
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-13 Sun 12:30')))
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-14 Mon 10:30')))
    local first_heading = orgfile:get_item(1)
    local second_heading = orgfile:get_item(3)
    local third_heading = orgfile:get_item(5)

    local time = Date.from_string('2021-07-14 Mon 12:20')
    local tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = {'OFFICE'},
        range = Range:new({ start_line = 1, end_line = 2 }),
        original_time = first_heading.dates[1],
        time = first_heading.dates[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 10,
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        range = Range:new({ start_line = 3, end_line = 4 }),
        original_time = second_heading.dates[1],
        time = second_heading.dates[1],
        type = 'SCHEDULED',
        reminder_type = 'time',
        minutes = 10,
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6 }),
        original_time = third_heading.dates[1],
        time = third_heading.dates[1]:with_negative_adjustment():without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'warning',
        minutes = 10,
      },
    }, tasks)

    config:extend({
      notifications = {
        reminder_time = false,
        deadline_warning_reminder_time = false,
        repeater_reminder_time = {10, 5, 0},
      }
    })

    time = Date.from_string('2021-07-14 Mon 12:20')
    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = {'OFFICE'},
        range = Range:new({ start_line = 1, end_line = 2 }),
        original_time = first_heading.dates[1],
        time = first_heading.dates[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 10,
      },
    }, tasks)

    config:extend({
      notifications = {
        reminder_time = 10,
        deadline_warning_reminder_time = {10, 5, 0},
        repeater_reminder_time = {10, 5, 0},
      }
    })

    time = Date.from_string('2021-07-14 Mon 12:20')
    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = {'OFFICE'},
        range = Range:new({ start_line = 1, end_line = 2 }),
        original_time = first_heading.dates[1],
        time = first_heading.dates[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 10,
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        range = Range:new({ start_line = 3, end_line = 4 }),
        original_time = second_heading.dates[1],
        time = second_heading.dates[1],
        type = 'SCHEDULED',
        reminder_type = 'time',
        minutes = 10,
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6 }),
        original_time = third_heading.dates[1],
        time = third_heading.dates[1]:with_negative_adjustment():without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'warning',
        minutes = 10,
      },
    }, tasks)
  end)

  it('should allow disabling specific reminder types', function()
    local orgfile = Files.get(last_filename)
    local notifications = Notifications:new()
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-13 Sun 12:30')))
    assert.are.same({}, notifications:get_tasks(Date.from_string('2021-07-14 Mon 10:30')))
    local first_heading = orgfile:get_item(1)
    local second_heading = orgfile:get_item(3)
    local third_heading = orgfile:get_item(5)

    local time = Date.from_string('2021-07-14 Mon 12:20')
    local tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = {'OFFICE'},
        range = Range:new({ start_line = 1, end_line = 2 }),
        original_time = first_heading.dates[1],
        time = first_heading.dates[1]:apply_repeater_until(time):without_adjustments(),
        minutes = 10,
        type = 'DEADLINE',
        reminder_type = 'repeater',
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        range = Range:new({ start_line = 3, end_line = 4 }),
        original_time = second_heading.dates[1],
        time = second_heading.dates[1],
        type = 'SCHEDULED',
        minutes = 10,
        reminder_type = 'time',
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6 }),
        original_time = third_heading.dates[1],
        time = third_heading.dates[1]:with_negative_adjustment():without_adjustments(),
        type = 'DEADLINE',
        minutes = 10,
        reminder_type = 'warning',
      },
    }, tasks)

    config:extend({
      notifications = {
        deadline_reminder = false,
      }
    })

    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the scheduled task',
        tags = {},
        range = Range:new({ start_line = 3, end_line = 4 }),
        original_time = second_heading.dates[1],
        time = second_heading.dates[1],
        type = 'SCHEDULED',
        reminder_type = 'time',
        minutes = 10,
      },
    }, tasks)

    config:extend({
      notifications = {
        scheduled_reminder = false,
        deadline_reminder = true,
      }
    })

    tasks = notifications:get_tasks(time)

    assert.are.same({
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task',
        tags = {'OFFICE'},
        range = Range:new({ start_line = 1, end_line = 2 }),
        original_time = first_heading.dates[1],
        time = first_heading.dates[1]:apply_repeater_until(time):without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'repeater',
        minutes = 10,
      },
      {
        file = last_filename,
        todo = 'TODO',
        category = 'work',
        level = 1,
        priority = '',
        title = 'I am the deadline task for evening',
        tags = {},
        range = Range:new({ start_line = 5, end_line = 6 }),
        original_time = third_heading.dates[1],
        time = third_heading.dates[1]:with_negative_adjustment():without_adjustments(),
        type = 'DEADLINE',
        reminder_type = 'warning',
        minutes = 10,
      },
    }, tasks)
  end)
end)


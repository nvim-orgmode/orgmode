local Date = require('orgmode.objects.date')
local Range = require('orgmode.files.elements.range')
local function get_timestamp(year, month, day, hour, min)
  return os.time({ year = year, month = month, day = day, hour = hour or 0, min = min or 0 })
end

describe('Date object', function()
  it('shoud parse date', function()
    local date = '2021-06-10'
    local result = Date.from_string(date)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(10, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.are.same('Thu', result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(get_timestamp(2021, 6, 10), result.timestamp)
    assert.are.same('2021-06-10 Thu', result:to_string())
    assert.are.same({}, result.adjustments)

    local date_with_dayname = '2021-06-10 Thu'
    local result_with_dayname = Date.from_string(date_with_dayname)
    assert.are.same(2021, result_with_dayname.year)
    assert.are.same(6, result_with_dayname.month)
    assert.are.same(10, result_with_dayname.day)
    assert.are.same(0, result_with_dayname.hour)
    assert.are.same(0, result_with_dayname.min)
    assert.are.same('Thu', result_with_dayname.dayname)
    assert.are.same(true, result_with_dayname.date_only)
    assert.are.same(get_timestamp(2021, 6, 10), result_with_dayname.timestamp)
    assert.are.same(date_with_dayname, result_with_dayname:to_string())
    assert.are.same({}, result_with_dayname.adjustments)
  end)

  it('should parse date time', function()
    local date = '2021-07-05 09:00'
    local result = Date.from_string(date)
    assert.are.same(2021, result.year)
    assert.are.same(7, result.month)
    assert.are.same(5, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(get_timestamp(2021, 7, 5, 9), result.timestamp)
    assert.are.same('2021-07-05 Mon 09:00', result:to_string())
    assert.are.same({}, result.adjustments)

    local date_with_dayname = '2021-07-05 Mon 09:00'
    local result_with_dayname = Date.from_string(date_with_dayname)
    assert.are.same(2021, result_with_dayname.year)
    assert.are.same(7, result_with_dayname.month)
    assert.are.same(5, result_with_dayname.day)
    assert.are.same(9, result_with_dayname.hour)
    assert.are.same(0, result_with_dayname.min)
    assert.are.same(false, result_with_dayname.date_only)
    assert.are.same(get_timestamp(2021, 7, 5, 9), result_with_dayname.timestamp)
    assert.are.same(date_with_dayname, result_with_dayname:to_string())
    assert.are.same({}, result_with_dayname.adjustments)
  end)

  it('should parse date time with dayname and warning adjustment', function()
    local date = '2021-06-30 Wed 09:00 -1d'
    local result = Date.from_string(date)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(get_timestamp(2021, 6, 30, 9), result.timestamp)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(date, result:to_string())
    assert.are.same({ '-1d' }, result.adjustments)
  end)

  it('should parse date time with dayname repeat adjustment', function()
    local date = '2021-06-30 Wed 09:00 +1m'
    local result = Date.from_string(date)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(get_timestamp(2021, 6, 30, 9), result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same({ '+1m' }, result.adjustments)
  end)

  it('should parse date time with dayname and both repeat and warning adjustment', function()
    local date = '2021-06-30 Wed 09:00 +1m -1d'
    local result = Date.from_string(date)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(get_timestamp(2021, 6, 30, 9), result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same({ '+1m', '-1d' }, result.adjustments)
  end)

  it('should parse date time with dayname and catch-up adjustment', function()
    local date = '2021-06-30 Wed 09:00 ++5d'
    local result = Date.from_string(date)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(get_timestamp(2021, 6, 30, 9), result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same({ '++5d' }, result.adjustments)
  end)

  it('should parse date time with dayname and restart adjustment', function()
    local date = '2021-06-30 Wed 09:00 .+1m'
    local result = Date.from_string(date)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(get_timestamp(2021, 6, 30, 9), result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same({ '.+1m' }, result.adjustments)
  end)

  it('should adjust date', function()
    local date = '2021-06-10'
    local result = Date.from_string(date)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(10, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.are.same('Thu', result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(get_timestamp(2021, 6, 10), result.timestamp)
    assert.are.same('2021-06-10 Thu', result:to_string())
    assert.are.same({}, result.adjustments)

    result = result:adjust('+1d')
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(11, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.are.same('Fri', result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(get_timestamp(2021, 6, 11), result.timestamp)
    assert.are.same('2021-06-11 Fri', result:to_string())
    assert.are.same({}, result.adjustments)

    result = result:adjust('+3m')
    assert.are.same(2021, result.year)
    assert.are.same(9, result.month)
    assert.are.same(11, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.are.same('Sat', result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(get_timestamp(2021, 9, 11), result.timestamp)
    assert.are.same('2021-09-11 Sat', result:to_string())
    assert.are.same({}, result.adjustments)

    result = result:adjust('-1w')
    assert.are.same(2021, result.year)
    assert.are.same(9, result.month)
    assert.are.same(4, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.are.same('Sat', result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(get_timestamp(2021, 9, 4), result.timestamp)
    assert.are.same('2021-09-04 Sat', result:to_string())
    assert.are.same({}, result.adjustments)

    result = result:adjust('+2y')
    assert.are.same(2023, result.year)
    assert.are.same(9, result.month)
    assert.are.same(4, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.are.same('Mon', result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(get_timestamp(2023, 9, 4), result.timestamp)
    assert.are.same('2023-09-04 Mon', result:to_string())
    assert.are.same({}, result.adjustments)

    result = result:adjust('+2')
    assert.are.same(2023, result.year)
    assert.are.same(9, result.month)
    assert.are.same(6, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.are.same('Wed', result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(get_timestamp(2023, 9, 6), result.timestamp)
    assert.are.same('2023-09-06 Wed', result:to_string())
    assert.are.same({}, result.adjustments)
  end)

  it('should adjust date time', function()
    local date = '2021-06-30 Wed 09:00 +1m'
    local result = Date.from_string(date)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(get_timestamp(2021, 6, 30, 9), result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same({ '+1m' }, result.adjustments)

    result = result:adjust('+1d')
    assert.are.same(2021, result.year)
    assert.are.same(7, result.month)
    assert.are.same(1, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(get_timestamp(2021, 7, 1, 9), result.timestamp)
    assert.are.same('2021-07-01 Thu 09:00 +1m', result:to_string())
    assert.are.same({ '+1m' }, result.adjustments)

    result = result:adjust('+2w')
    assert.are.same(2021, result.year)
    assert.are.same(7, result.month)
    assert.are.same(15, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(get_timestamp(2021, 7, 15, 9), result.timestamp)
    assert.are.same('2021-07-15 Thu 09:00 +1m', result:to_string())
    assert.are.same({ '+1m' }, result.adjustments)

    result = result:adjust('-3h')
    assert.are.same(2021, result.year)
    assert.are.same(7, result.month)
    assert.are.same(15, result.day)
    assert.are.same(6, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(get_timestamp(2021, 7, 15, 6), result.timestamp)
    assert.are.same('2021-07-15 Thu 06:00 +1m', result:to_string())
    assert.are.same({ '+1m' }, result.adjustments)

    result = result:adjust('+3y')
    assert.are.same(2024, result.year)
    assert.are.same(7, result.month)
    assert.are.same(15, result.day)
    assert.are.same(6, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(get_timestamp(2024, 7, 15, 6), result.timestamp)
    assert.are.same('2024-07-15 Mon 06:00 +1m', result:to_string())
    assert.are.same({ '+1m' }, result.adjustments)

    result = result:adjust('-1m')
    assert.are.same(2024, result.year)
    assert.are.same(6, result.month)
    assert.are.same(15, result.day)
    assert.are.same(6, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(get_timestamp(2024, 6, 15, 6), result.timestamp)
    assert.are.same('2024-06-15 Sat 06:00 +1m', result:to_string())
    assert.are.same({ '+1m' }, result.adjustments)
  end)

  it('should get start of specific range', function()
    local date = Date.from_string('2021-05-12 10:30')
    date = date:start_of('day')
    assert.are.same('2021-05-12 Wed 00:00', date:to_string())
    date = date:start_of('week')
    assert.are.same('2021-05-10 Mon 00:00', date:to_string())
    date = date:start_of('month')
    assert.are.same('2021-05-01 Sat 00:00', date:to_string())
    date = date:start_of('year')
    assert.are.same('2021-01-01 Fri 00:00', date:to_string())
    date = Date.from_string('2021-05-12 10:30')
    date = date:start_of('month')
    assert.are.same('2021-05-01 Sat 00:00', date:to_string())
  end)

  it('should get end of specific range', function()
    local date = Date.from_string('2021-05-12 09:00')
    date = date:end_of('day')
    assert.are.same('2021-05-12 Wed 23:59', date:to_string())
    date = date:end_of('week')
    assert.are.same('2021-05-16 Sun 23:59', date:to_string())
    date = date:end_of('month')
    assert.are.same('2021-05-31 Mon 23:59', date:to_string())
    date = date:end_of('year')
    assert.are.same('2021-12-31 Fri 23:59', date:to_string())
    date = Date.from_string('2021-05-12 09:00')
    date = date:end_of('month')
    assert.are.same('2021-05-31 Mon 23:59', date:to_string())
  end)

  it('should add/subtract/set date', function()
    local date = Date.from_string('2021-05-12 14:00')
    date = date:add({ week = 2 })
    assert.are.same('2021-05-26 Wed 14:00', date:to_string())
    date = date:add({ month = 2 })
    assert.are.same('2021-07-26 Mon 14:00', date:to_string())
    date = date:add({ year = 1 })
    assert.are.same('2022-07-26 Tue 14:00', date:to_string())
    date = date:subtract({ hour = 1 })
    assert.are.same('2022-07-26 Tue 13:00', date:to_string())
    date = date:subtract({ min = 30 })
    assert.are.same('2022-07-26 Tue 12:30', date:to_string())
    date = date:subtract({ month = 4 })
    assert.are.same('2022-03-26 Sat 12:30', date:to_string())
    date = date:subtract({ year = 2 })
    assert.are.same('2020-03-26 Thu 12:30', date:to_string())
  end)

  it('should compare dates', function()
    local date = Date.from_string('2021-05-12 14:00')
    local date_end = Date.from_string('2021-05-12 23:30')
    local from = Date.from_string('2021-05-10 14:00')
    local to = Date.from_string('2021-05-15 14:00')

    assert.is.True(date:is_between(from, to))
    assert.is.True(from:is_before(date))
    assert.is.True(from:is_same_or_before(date))
    assert.is.True(to:is_after(date))
    assert.is.True(to:is_same_or_after(date))
    assert.is.True(date:is_same_or_before(date))
    assert.is.True(date:is_same_or_after(date))
    assert.is.True(date:is_same(date))
    assert.is.False(date:is_same(date_end))
    assert.is.False(date:is_same(date_end, 'hour'))
    assert.is.True(date:is_same(date_end, 'day'))
    assert.is.True(from:is_same(date, 'month'))
    assert.is.True(to:is_same(date, 'month'))
    assert.is.True(from:is_same(date, 'year'))
    assert.is.True(to:is_same(date, 'year'))
    assert.is.False(from:is_today())
    assert.is.True(Date.now():is_today())
  end)

  it('should generate date range', function()
    local date = Date.from_string('2021-05-12 14:00')
    local end_date = date:adjust('+1w')
    local dates = date:get_range_until(end_date)
    assert.are.same(7, #dates)
    assert.are.same({
      Date.from_string('2021-05-12 14:00'),
      Date.from_string('2021-05-13 14:00'),
      Date.from_string('2021-05-14 14:00'),
      Date.from_string('2021-05-15 14:00'),
      Date.from_string('2021-05-16 14:00'),
      Date.from_string('2021-05-17 14:00'),
      Date.from_string('2021-05-18 14:00'),
    }, dates)
  end)

  it('should return proper diff in days between DST difference', function()
    -- No overlap
    local date = Date.from_string('2023-06-26')
    local end_date = Date.from_string('2023-06-27')
    assert.are.same(1, end_date:diff(date))
    assert.are.same(1440, end_date:diff(date, 'minute'))

    -- DST start overlap
    local date_no_dst = Date.from_string('2023-03-26 Sun')
    local end_date_dst = Date.from_string('2023-03-27 Mon')
    assert.are.same(1, end_date_dst:diff(date_no_dst))
    assert.are.same(1440, end_date_dst:diff(date_no_dst, 'minute'))

    -- DST end overlap
    local date_dst = Date.from_string('2023-10-28 Sun')
    local end_date_no_dst = Date.from_string('2023-10-29 Mon')
    assert.are.same(1, end_date_no_dst:diff(date_dst))
    assert.are.same(1440, end_date_no_dst:diff(date_dst, 'minute'))
  end)

  it('should format the date', function()
    local date = Date.from_string('2021-05-12 14:00')
    assert.are.same('Wednesday 12 May', date:format('%A %d %B'))
    assert.are.same('12 of May', date:format('%d of %B'))
  end)

  it('should humanize the date duration', function()
    local date = Date.from_string('2021-05-12 14:00')
    local now = Date.from_string('2021-05-12 14:00')
    assert.are.same('Today', date:humanize(now))
    date = date:add({ day = 1 })
    assert.are.same('In 1 d.', date:humanize(now))
    date = date:add({ week = 1 })
    assert.are.same('In 8 d.', date:humanize(now))
    date = date:add({ month = 1 })
    assert.are.same('In 39 d.', date:humanize(now))
    date = date:subtract({ month = 2 })
    assert.are.same('22 d. ago', date:humanize(now))
    date = date:add({ week = 2 })
    assert.are.same('8 d. ago', date:humanize(now))
  end)

  it('should parse single date from line', function()
    local line = 'This is some line and has a date <2021-05-15 Sat> that is active'
    local dates = Date.parse_all_from_line(line, 1)
    assert.are.same(1, #dates)
    assert.are.same({
      active = true,
      adjustments = {},
      date_only = true,
      day = 15,
      dayname = 'Sat',
      is_dst = true,
      hour = 0,
      min = 0,
      month = 5,
      is_date_range_start = false,
      is_date_range_end = false,
      related_date_range = nil,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 34,
        end_col = 49,
      }),
      timestamp = get_timestamp(2021, 5, 15),
      type = 'NONE',
      year = 2021,
    }, dates[1])
  end)

  it('should parse multiple dates from line', function()
    local line =
      'This is some line and has a date <2021-05-15 Sat> that is active and has a date [2021-06-15 Tue 09:25] that is inactive'
    local dates = Date.parse_all_from_line(line, 1)
    assert.are.same(2, #dates)
    assert.are.same({
      active = true,
      adjustments = {},
      date_only = true,
      day = 15,
      dayname = 'Sat',
      hour = 0,
      min = 0,
      is_dst = true,
      month = 5,
      is_date_range_start = false,
      is_date_range_end = false,
      related_date_range = nil,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 34,
        end_col = 49,
      }),
      timestamp = get_timestamp(2021, 5, 15),
      type = 'NONE',
      year = 2021,
    }, dates[1])
    assert.are.same({
      active = false,
      adjustments = {},
      date_only = false,
      day = 15,
      dayname = 'Tue',
      hour = 9,
      min = 25,
      month = 6,
      is_dst = true,
      is_date_range_start = false,
      is_date_range_end = false,
      related_date_range = nil,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 81,
        end_col = 102,
      }),
      timestamp = get_timestamp(2021, 6, 15, 9, 25),
      type = 'NONE',
      year = 2021,
    }, dates[2])
  end)

  it('should parse multiple dates from line and setup proper range with same dates', function()
    local line =
      'This is some line and has a date <2021-05-15 Sat> and again has the same date <2021-05-15 Sat> for no reason'
    local dates = Date.parse_all_from_line(line, 1)
    assert.are.same(2, #dates)
    assert.are.same({
      active = true,
      adjustments = {},
      date_only = true,
      day = 15,
      dayname = 'Sat',
      hour = 0,
      min = 0,
      is_dst = true,
      month = 5,
      is_date_range_start = false,
      is_date_range_end = false,
      related_date_range = nil,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 34,
        end_col = 49,
      }),
      timestamp = get_timestamp(2021, 5, 15),
      type = 'NONE',
      year = 2021,
    }, dates[1])
    assert.are.same({
      active = true,
      adjustments = {},
      date_only = true,
      day = 15,
      dayname = 'Sat',
      hour = 0,
      min = 0,
      month = 5,
      is_dst = true,
      is_date_range_start = false,
      is_date_range_end = false,
      related_date_range = nil,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 79,
        end_col = 94,
      }),
      timestamp = get_timestamp(2021, 5, 15),
      type = 'NONE',
      year = 2021,
    }, dates[2])
  end)

  it('should set and get isoweekday', function()
    local sunday = Date.from_string('2021-05-16')
    assert.are.same(7, sunday:get_isoweekday())
    local monday = sunday:add({ day = 1 })
    assert.are.same(1, monday:get_isoweekday())
    local tuesday = monday:add({ day = 1 })
    assert.are.same(2, tuesday:get_isoweekday())

    monday = monday:set_isoweekday(1)
    assert.are.same(1, monday:get_isoweekday())
    assert.are.same('2021-05-17 Mon', monday:to_string())
    local thursday = monday:set_isoweekday(4, true)
    assert.are.same(4, thursday:get_isoweekday())
    assert.are.same('2021-05-20 Thu', thursday:to_string())
    local previous_saturday = monday:set_isoweekday(6)
    assert.are.same(6, previous_saturday:get_isoweekday())
    assert.are.same('2021-05-15 Sat', previous_saturday:to_string())
  end)

  it('should handle repeater', function()
    local sunday = Date.from_string('2021-05-16 +1w')
    assert.are.same('+1w', sunday:get_repeater())
    assert.is.True(sunday:repeats_on(sunday:add({ week = 1 })))
    assert.is.False(sunday:repeats_on(sunday:add({ day = 6 })))

    local saturday = Date.from_string('2021-05-15 Sat .+1w')
    assert.is.True(saturday:repeats_on(saturday:add({ week = 1 })))
    assert.is.False(saturday:repeats_on(saturday:add({ day = 5 })))

    local friday = Date.from_string('2021-05-14 Fri ++1w')
    assert.is.True(friday:repeats_on(friday:add({ week = 1 })))
    assert.is.False(friday:repeats_on(friday:add({ day = 5 })))
  end)

  it('should apply different types of repeaters to the date', function()
    local sunday = Date.from_string('2021-05-16 Sun 12:30 +1w')
    local next_sunday = sunday:apply_repeater()
    assert.are.same(next_sunday:to_string(), '2021-05-23 Sun 12:30 +1w')

    local saturday = Date.from_string('2021-05-15 Sat 13:30 .+1w')
    local week_in_future = saturday:apply_repeater()
    local expect_week = Date.now():add({ week = 1 }):set({ hour = 13, min = 30 })
    expect_week = Date.from_string(expect_week:to_string() .. ' .+1w')
    assert.are.same(week_in_future:to_string(), expect_week:to_string())

    local friday = Date.from_string('2021-05-14 Fri 14:45 ++1w')
    local closest_friday = friday:apply_repeater()
    assert.is.True(closest_friday:is_after(friday, 'day'))
    assert.is.True(closest_friday:diff(Date.now()) < 8)
  end)

  it('should apply repeater date until provided date', function()
    local sunday = Date.from_string('2022-06-19 Sun 12:30 +1w')
    local inTwoWeeks = Date.from_string('2022-06-26 Sun 12:30 +1w')
    assert.are.same(inTwoWeeks:to_string(), sunday:apply_repeater_until(inTwoWeeks):to_string())
  end)

  it('should apply repeater to future dates', function()
    local tomorrow = Date.now({ adjustments = { '++1d' } }):add({ day = 1 })
    local day_after_tomorrow = tomorrow:add({ day = 1 })
    local updated_date = tomorrow:apply_repeater()
    assert.are.same(updated_date:to_string(), day_after_tomorrow:to_string())
  end)

  it('should cache check for today', function()
    local today = Date.today()
    assert.is.Nil(today.is_today_date)
    assert.is.True(today:is_today())
    assert.is.True(today.is_today_date)

    local future_date = Date.today():add({ day = 5 })
    assert.is.Nil(future_date.is_today_date)
    assert.is.False(future_date:is_today())
    assert.is.False(future_date.is_today_date)
  end)

  it('should handle time range', function()
    local sunday = Date.from_string('2021-05-16 Sun 12:30-13:30 +1w')
    assert.are.same(sunday.timestamp + 3600, sunday.timestamp_end)
    assert.are.same({ '+1w' }, sunday.adjustments)
    assert.are.same('2021-05-16 Sun 12:30-13:30 +1w', sunday:to_string())
    assert.are.same('12:30-13:30', sunday:format_time())
    local monday = sunday:adjust('+1d')
    assert.are.same(monday.timestamp + 3600, monday.timestamp_end)
    assert.are.same({ '+1w' }, monday.adjustments)
    assert.are.same('2021-05-17 Mon 12:30-13:30 +1w', monday:to_string())
    assert.are.same('12:30-13:30', monday:format_time())
    local thursday = sunday:adjust('-3d')
    assert.are.same(thursday.timestamp + 3600, thursday.timestamp_end)
    assert.are.same({ '+1w' }, thursday.adjustments)
    assert.are.same('2021-05-13 Thu 12:30-13:30 +1w', thursday:to_string())
    assert.are.same('12:30-13:30', thursday:format_time())

    local monday_end_of_day = Date.from_string('2021-05-17 Mon 22:30-23:30 +1w')
    assert.are.same(monday_end_of_day.timestamp + 3600, monday_end_of_day.timestamp_end)
    assert.are.same({ '+1w' }, monday_end_of_day.adjustments)
    assert.are.same('2021-05-17 Mon 22:30-23:30 +1w', monday_end_of_day:to_string())
    assert.are.same('22:30-23:30', monday_end_of_day:format_time())
    local tuesday_morning = monday_end_of_day:adjust('+1h')
    assert.are.same(tuesday_morning.timestamp + 3600, tuesday_morning.timestamp_end)
    assert.are.same({ '+1w' }, tuesday_morning.adjustments)
    assert.are.same('2021-05-17 Mon 23:30-00:30 +1w', tuesday_morning:to_string())
    assert.are.same('23:30-00:30', tuesday_morning:format_time())

    local line =
      'This line has a date rang <2021-05-15 Sat 14:30-15:30 +1w> and again has some date <2021-05-17 Mon> for no reason'
    local dates = Date.parse_all_from_line(line, 1)
    assert.are.same(2, #dates)
    assert.are.same({
      active = true,
      adjustments = { '+1w' },
      date_only = false,
      day = 15,
      dayname = 'Sat',
      hour = 14,
      min = 30,
      is_dst = true,
      month = 5,
      is_date_range_start = false,
      is_date_range_end = false,
      related_date_range = nil,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 27,
        end_col = 58,
      }),
      timestamp = get_timestamp(2021, 5, 15, 14, 30),
      timestamp_end = get_timestamp(2021, 5, 15, 15, 30),
      type = 'NONE',
      year = 2021,
    }, dates[1])
    assert.are.same({
      active = true,
      adjustments = {},
      date_only = true,
      day = 17,
      dayname = 'Mon',
      hour = 0,
      min = 0,
      month = 5,
      is_dst = true,
      is_date_range_start = false,
      is_date_range_end = false,
      related_date_range = nil,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 84,
        end_col = 99,
      }),
      timestamp = get_timestamp(2021, 5, 17),
      type = 'NONE',
      year = 2021,
    }, dates[2])
  end)

  it('should parse date range from line', function()
    local line =
      'This line has a date rang <2021-05-15 Sat>--<2021-05-16 Sun> and again has some date <2021-05-17 Mon> for no reason'
    local dates = Date.parse_all_from_line(line, 1)
    assert.are.same(3, #dates)
    assert.are.same({
      active = true,
      adjustments = {},
      date_only = true,
      day = 15,
      dayname = 'Sat',
      hour = 0,
      is_dst = true,
      min = 0,
      month = 5,
      is_date_range_start = true,
      is_date_range_end = false,
      related_date_range = dates[2],
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 27,
        end_col = 42,
      }),
      timestamp = get_timestamp(2021, 5, 15),
      type = 'NONE',
      year = 2021,
    }, dates[1])
    assert.are.same({
      active = true,
      adjustments = {},
      date_only = true,
      day = 16,
      dayname = 'Sun',
      hour = 0,
      min = 0,
      month = 5,
      is_dst = true,
      is_date_range_start = false,
      is_date_range_end = true,
      related_date_range = dates[1],
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 45,
        end_col = 60,
      }),
      timestamp = get_timestamp(2021, 5, 16),
      type = 'NONE',
      year = 2021,
    }, dates[2])
    assert.are.same({
      active = true,
      adjustments = {},
      date_only = true,
      day = 17,
      dayname = 'Mon',
      hour = 0,
      min = 0,
      month = 5,
      is_date_range_start = false,
      is_date_range_end = false,
      related_date_range = nil,
      is_dst = true,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 86,
        end_col = 101,
      }),
      timestamp = get_timestamp(2021, 5, 17),
      type = 'NONE',
      year = 2021,
    }, dates[3])
  end)

  it('should allow diffing time in minutes', function()
    local from = Date.from_string('2021-12-07 Mon 10:00')
    local to = Date.from_string('2021-12-07 Mon 10:25')
    assert.are.same(25, to:diff(from, 'minute'))

    from = Date.from_string('2021-12-07 Mon 10:00')
    to = Date.from_string('2021-12-07 Mon 12:35')
    assert.are.same(155, to:diff(from, 'minute'))
  end)

  it('should properly calculate week number', function()
    local first = Date.from_string('2021-09-19')
    assert.are.same('37', first:get_week_number())

    local start_of_2020 = Date.from_string('2020-01-01')
    assert.are.same('01', start_of_2020:get_week_number())

    local february_2020 = Date.from_string('2020-02-28')
    assert.are.same('09', february_2020:get_week_number())

    local november_2020 = Date.from_string('2020-11-30')
    assert.are.same('49', november_2020:get_week_number())

    local end_of_2020 = Date.from_string('2020-12-31')
    assert.are.same('53', end_of_2020:get_week_number())

    local start_of_2021 = Date.from_string('2021-01-01')
    assert.are.same('53', start_of_2021:get_week_number())

    local february_2021 = Date.from_string('2021-02-28')
    assert.are.same('08', february_2021:get_week_number())

    local august_2021 = Date.from_string('2021-08-31')
    assert.are.same('35', august_2021:get_week_number())

    local end_of_2021 = Date.from_string('2021-12-31')
    assert.are.same('52', end_of_2021:get_week_number())
  end)
end)

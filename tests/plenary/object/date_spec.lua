local Date = require('orgmode.objects.date')
local Range = require('orgmode.parser.range')
describe('Date object', function()
  it('shoud parse date', function()
    local date = '2021-06-10'
    local result = Date.from_string(date)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(10, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.is.Nil(result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(1623276000, result.timestamp)
    assert.are.same(date, result:to_string())
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
    assert.are.same(1623276000, result_with_dayname.timestamp)
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
    assert.are.same(1625468400, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same({}, result.adjustments)

    local date_with_dayname = '2021-07-05 Mon 09:00'
    local result_with_dayname = Date.from_string(date_with_dayname)
    assert.are.same(2021, result_with_dayname.year)
    assert.are.same(7, result_with_dayname.month)
    assert.are.same(5, result_with_dayname.day)
    assert.are.same(9, result_with_dayname.hour)
    assert.are.same(0, result_with_dayname.min)
    assert.are.same(false, result_with_dayname.date_only)
    assert.are.same(1625468400, result_with_dayname.timestamp)
    assert.are.same(date_with_dayname, result_with_dayname:to_string())
    assert.are.same({}, result_with_dayname.adjustments)
  end)

  it('should parse date time with dayname and warning adjustment', function()
    local date = '2021-06-30 Wed 09:00 -1d'
    local result = Date.from_string(date)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(date, result:to_string())
    assert.are.same({'-1d'}, result.adjustments)
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
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same({'+1m'}, result.adjustments)
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
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same({'+1m', '-1d'}, result.adjustments)
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
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same({'++5d'}, result.adjustments)
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
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same({'.+1m'}, result.adjustments)
  end)

  it('should adjust date', function()
    local date = '2021-06-10'
    local result = Date.from_string(date)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(10, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.is.Nil(result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(1623276000, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same({}, result.adjustments)

    result = result:adjust('+1d')
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(11, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.is.Nil(result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(1623362400, result.timestamp)
    assert.are.same('2021-06-11', result:to_string())
    assert.are.same({}, result.adjustments)

    result = result:adjust('+3m')
    assert.are.same(2021, result.year)
    assert.are.same(9, result.month)
    assert.are.same(11, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.is.Nil(result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(1631311200, result.timestamp)
    assert.are.same('2021-09-11', result:to_string())
    assert.are.same({}, result.adjustments)

    result = result:adjust('-1w')
    assert.are.same(2021, result.year)
    assert.are.same(9, result.month)
    assert.are.same(4, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.is.Nil(result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(1630706400, result.timestamp)
    assert.are.same('2021-09-04', result:to_string())
    assert.are.same({}, result.adjustments)

    result = result:adjust('+2y')
    assert.are.same(2023, result.year)
    assert.are.same(9, result.month)
    assert.are.same(4, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.is.Nil(result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(1693778400, result.timestamp)
    assert.are.same('2023-09-04', result:to_string())
    assert.are.same({}, result.adjustments)

    result = result:adjust('+2')
    assert.are.same(2023, result.year)
    assert.are.same(9, result.month)
    assert.are.same(6, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.is.Nil(result.dayname)
    assert.are.same(true, result.date_only)
    assert.are.same(1693951200, result.timestamp)
    assert.are.same('2023-09-06', result:to_string())
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
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same({'+1m'}, result.adjustments)

    result = result:adjust('+1d')
    assert.are.same(2021, result.year)
    assert.are.same(7, result.month)
    assert.are.same(1, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1625122800, result.timestamp)
    assert.are.same("2021-07-01 Thu 09:00 +1m", result:to_string())
    assert.are.same({'+1m'}, result.adjustments)

    result = result:adjust('+2w')
    assert.are.same(2021, result.year)
    assert.are.same(7, result.month)
    assert.are.same(15, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1626332400, result.timestamp)
    assert.are.same("2021-07-15 Thu 09:00 +1m", result:to_string())
    assert.are.same({'+1m'}, result.adjustments)

    result = result:adjust('-3h')
    assert.are.same(2021, result.year)
    assert.are.same(7, result.month)
    assert.are.same(15, result.day)
    assert.are.same(6, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1626321600, result.timestamp)
    assert.are.same("2021-07-15 Thu 06:00 +1m", result:to_string())
    assert.are.same({'+1m'}, result.adjustments)

    result = result:adjust('+3y')
    assert.are.same(2024, result.year)
    assert.are.same(7, result.month)
    assert.are.same(15, result.day)
    assert.are.same(6, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1721016000, result.timestamp)
    assert.are.same("2024-07-15 Mon 06:00 +1m", result:to_string())
    assert.are.same({'+1m'}, result.adjustments)

    result = result:adjust('-1m')
    assert.are.same(2024, result.year)
    assert.are.same(6, result.month)
    assert.are.same(15, result.day)
    assert.are.same(6, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1718424000, result.timestamp)
    assert.are.same("2024-06-15 Sat 06:00 +1m", result:to_string())
    assert.are.same({'+1m'}, result.adjustments)
  end)

  it('should get start of specific range', function()
    local date = Date.from_string('2021-05-12 10:30')
    date = date:start_of('day')
    assert.are.same('2021-05-12 00:00', date:to_string())
    date = date:start_of('week')
    assert.are.same('2021-05-10 00:00', date:to_string())
    date = date:start_of('month')
    assert.are.same('2021-05-01 00:00', date:to_string())
    date = date:start_of('year')
    assert.are.same('2021-01-01 00:00', date:to_string())
    date = Date.from_string('2021-05-12 10:30')
    date = date:start_of('month')
    assert.are.same('2021-05-01 00:00', date:to_string())
  end)

  it('should get end of specific range', function()
    local date = Date.from_string('2021-05-12 09:00')
    date = date:end_of('day')
    assert.are.same('2021-05-12 23:59', date:to_string())
    date = date:end_of('week')
    assert.are.same('2021-05-16 23:59', date:to_string())
    date = date:end_of('month')
    assert.are.same('2021-05-31 23:59', date:to_string())
    date = date:end_of('year')
    assert.are.same('2021-12-31 23:59', date:to_string())
    date = Date.from_string('2021-05-12 09:00')
    date = date:end_of('month')
    assert.are.same('2021-05-31 23:59', date:to_string())
  end)

  it('should add/subtract/set date', function()
    local date = Date.from_string('2021-05-12 14:00')
    date = date:add({ week = 2 })
    assert.are.same('2021-05-26 14:00', date:to_string())
    date = date:add({ month = 2 })
    assert.are.same('2021-07-26 14:00', date:to_string())
    date = date:add({ year = 1 })
    assert.are.same('2022-07-26 14:00', date:to_string())
    date = date:subtract({ hour = 1 })
    assert.are.same('2022-07-26 13:00', date:to_string())
    date = date:subtract({ min = 30 })
    assert.are.same('2022-07-26 12:30', date:to_string())
    date = date:subtract({ month = 4 })
    assert.are.same('2022-03-26 12:30', date:to_string())
    date = date:subtract({ year = 2 })
    assert.are.same('2020-03-26 12:30', date:to_string())
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
      dayname = "Sat",
      hour = 0,
      min = 0,
      month = 5,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 34,
        end_col = 49
      }),
      timestamp = 1621029600,
      type = "NONE",
      year = 2021,
    }, dates[1])
  end)

  it('should parse multiple dates from line', function()
    local line = 'This is some line and has a date <2021-05-15 Sat> that is active and has a date [2021-06-15 Tue 09:25] that is inactive'
    local dates = Date.parse_all_from_line(line, 1)
    assert.are.same(2, #dates)
    assert.are.same({
      active = true,
      adjustments = {},
      date_only = true,
      day = 15,
      dayname = "Sat",
      hour = 0,
      min = 0,
      month = 5,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 34,
        end_col = 49
      }),
      timestamp = 1621029600,
      type = "NONE",
      year = 2021,
    }, dates[1])
    assert.are.same({
      active = false,
      adjustments = {},
      date_only = false,
      day = 15,
      dayname = "Tue",
      hour = 9,
      min = 25,
      month = 6,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 81,
        end_col = 102
      }),
      timestamp = 1623741900,
      type = "NONE",
      year = 2021,
    }, dates[2])
  end)

  it('should parse multiple dates from line and setup proper range with same dates', function()
    local line = 'This is some line and has a date <2021-05-15 Sat> and again has the same date <2021-05-15 Sat> for no reason'
    local dates = Date.parse_all_from_line(line, 1)
    assert.are.same(2, #dates)
    assert.are.same({
      active = true,
      adjustments = {},
      date_only = true,
      day = 15,
      dayname = "Sat",
      hour = 0,
      min = 0,
      month = 5,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 34,
        end_col = 49
      }),
      timestamp = 1621029600,
      type = "NONE",
      year = 2021,
    }, dates[1])
    assert.are.same({
      active = true,
      adjustments = {},
      date_only = true,
      day = 15,
      dayname = "Sat",
      hour = 0,
      min = 0,
      month = 5,
      range = Range:new({
        start_line = 1,
        end_line = 1,
        start_col = 79,
        end_col = 94
      }),
      timestamp = 1621029600,
      type = "NONE",
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
    assert.are.same('2021-05-17', monday:to_string())
    local thursday = monday:set_isoweekday(4, true)
    assert.are.same(4, thursday:get_isoweekday())
    assert.are.same('2021-05-20', thursday:to_string())
    local previous_saturday = monday:set_isoweekday(6)
    assert.are.same(6, previous_saturday:get_isoweekday())
    assert.are.same('2021-05-15', previous_saturday:to_string())
  end)

  it('should handle repeater', function()
    local sunday = Date.from_string('2021-05-16 +1w')
    assert.are.same('+1w', sunday:get_repeater())
    assert.is.True(sunday:repeats_on(sunday:add({ week = 1 })))
    assert.is.False(sunday:repeats_on(sunday:add({ day = 6 })))
  end)

  it('should cache check for today', function()
    local today = Date.today();
    assert.is.Nil(today.is_today_date)
    assert.is.True(today:is_today())
    assert.is.True(today.is_today_date)

    local future_date = Date.today():add({ day = 5 })
    assert.is.Nil(future_date.is_today_date)
    assert.is.False(future_date:is_today())
    assert.is.False(future_date.is_today_date)
  end)
end)

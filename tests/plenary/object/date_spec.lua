local Date = require('orgmode.objects.date')
describe('Date object', function()
  it('should parse date', function()
    local date = '2021-05-15 Sat'
    local result = Date:from_string(date)
    assert.are.same(date, result.original_value)
    assert.are.same(true, result.valid)
    assert.are.same(2021, result.year)
    assert.are.same(5, result.month)
    assert.are.same(15, result.day)
    assert.are.same(0, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(true, result.date_only)
    assert.are.same(1621029600, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.is.Nil(result.adjustment)
  end)

  it('should parse date time', function()
    local date = '2021-06-30 Wed 09:00'
    local result = Date:from_string(date)
    assert.are.same(date, result.original_value)
    assert.are.same(true, result.valid)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.is.Nil(result.adjustments)
  end)

  it('should parse date time with warning adjustment', function()
    local date = '2021-06-30 Wed 09:00 -1d'
    local result = Date:from_string(date)
    assert.are.same(date, result.original_value)
    assert.are.same(true, result.valid)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(date, result:to_string())
    assert.are.same('-1d', result.adjustment)
  end)

  it('should parse date time with repeat adjustment', function()
    local date = '2021-06-30 Wed 09:00 +1m'
    local result = Date:from_string(date)
    assert.are.same(date, result.original_value)
    assert.are.same(true, result.valid)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same('+1m', result.adjustment)
  end)

  it('should parse date time with both repeat and warning adjustment', function()
    local date = '2021-06-30 Wed 09:00 +1m -1d'
    local result = Date:from_string(date)
    assert.are.same(date, result.original_value)
    assert.are.same(true, result.valid)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same('+1m -1d', result.adjustment)
  end)

  it('should parse date time with both catch-up adjustment', function()
    local date = '2021-06-30 Wed 09:00 ++5d'
    local result = Date:from_string(date)
    assert.are.same(date, result.original_value)
    assert.are.same(true, result.valid)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same('++5d', result.adjustment)
  end)

  it('should parse date time with both restart adjustment', function()
    local date = '2021-06-30 Wed 09:00 .+1m'
    local result = Date:from_string(date)
    assert.are.same(date, result.original_value)
    assert.are.same(true, result.valid)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same('.+1m', result.adjustment)
  end)

  it('should adjust date', function()
    local date = '2021-06-30 Wed 09:00 +1m'
    local result = Date:from_string(date)
    assert.are.same(date, result.original_value)
    assert.are.same(true, result.valid)
    assert.are.same(2021, result.year)
    assert.are.same(6, result.month)
    assert.are.same(30, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1625036400, result.timestamp)
    assert.are.same(date, result:to_string())
    assert.are.same('+1m', result.adjustment)

    result = result:adjust('+1d')
    assert.are.same(true, result.valid)
    assert.are.same(2021, result.year)
    assert.are.same(7, result.month)
    assert.are.same(1, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1625122800, result.timestamp)
    assert.are.same("2021-07-01 Thu 09:00 +1m", result:to_string())
    assert.are.same('+1m', result.adjustment)

    result = result:adjust('+2w')
    assert.are.same(true, result.valid)
    assert.are.same(2021, result.year)
    assert.are.same(7, result.month)
    assert.are.same(15, result.day)
    assert.are.same(9, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1626332400, result.timestamp)
    assert.are.same("2021-07-15 Thu 09:00 +1m", result:to_string())
    assert.are.same('+1m', result.adjustment)

    result = result:adjust('-3h')
    assert.are.same(true, result.valid)
    assert.are.same(2021, result.year)
    assert.are.same(7, result.month)
    assert.are.same(15, result.day)
    assert.are.same(6, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1626321600, result.timestamp)
    assert.are.same("2021-07-15 Thu 06:00 +1m", result:to_string())
    assert.are.same('+1m', result.adjustment)

    result = result:adjust('+3y')
    assert.are.same(true, result.valid)
    assert.are.same(2024, result.year)
    assert.are.same(7, result.month)
    assert.are.same(15, result.day)
    assert.are.same(6, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1721016000, result.timestamp)
    assert.are.same("2024-07-15 Mon 06:00 +1m", result:to_string())
    assert.are.same('+1m', result.adjustment)

    result = result:adjust('-1m')
    assert.are.same(true, result.valid)
    assert.are.same(2024, result.year)
    assert.are.same(6, result.month)
    assert.are.same(15, result.day)
    assert.are.same(6, result.hour)
    assert.are.same(0, result.min)
    assert.are.same(false, result.date_only)
    assert.are.same(1718424000, result.timestamp)
    assert.are.same("2024-06-15 Sat 06:00 +1m", result:to_string())
    assert.are.same('+1m', result.adjustment)
  end)
end)

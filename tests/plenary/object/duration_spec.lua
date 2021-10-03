local Duration = require('orgmode.objects.duration')

describe('Duration', function()
  it('should parse duration from string', function()
    local result = Duration.parse('0:35')
    assert.is.Not.Nil(result)
    assert.are.same(result.minutes, 35)
    assert.are.same(result.parts, {
      hours = 0,
      minutes = 35,
    })

    result = Duration.parse('13:28')
    assert.is.Not.Nil(result)
    assert.are.same(result.minutes, 808)
    assert.are.same(result.parts, {
      hours = 13,
      minutes = 28,
    })

    result = Duration.parse('1d 2h')
    assert.is.Not.Nil(result)
    assert.are.same(result.minutes, 1560)
    assert.are.same(result.parts, {
      days = 1,
      hours = 2,
    })

    result = Duration.parse('2y 4m 2w 3d 15:25')
    assert.is.Not.Nil(result)
    assert.are.same(result.minutes, 1051200 + 172800 + 20160 + 4320 + 900 + 25)
    assert.are.same(result.parts, {
      years = 2,
      months = 4,
      weeks = 2,
      days = 3,
      hours = 15,
      minutes = 25,
    })

    result = Duration.parse('2y 4m 2w 3d 15h 25min')
    assert.is.Not.Nil(result)
    assert.are.same(result.minutes, 1051200 + 172800 + 20160 + 4320 + 900 + 25)
    assert.are.same(result.parts, {
      years = 2,
      months = 4,
      weeks = 2,
      days = 3,
      hours = 15,
      minutes = 25,
    })
  end)

  it('should properly return null when parsing invalid format', function()
    local result = Duration.parse('0-35')
    assert.is.Nil(result)

    result = Duration.parse('1d2invalid')
    assert.is.Nil(result)

    result = Duration.parse('abc')
    assert.is.Nil(result)

    result = Duration.parse('dd22aa')
    assert.is.Nil(result)
  end)

  it('should properly format duration to string', function()
    local result = Duration.parse('0:35')
    assert.are.same(result:to_string('HH:MM'), '0:35')
    assert.are.same(result:to_string(), '0:35')

    result = Duration.parse('13:28')
    assert.are.same(result:to_string('HH:MM'), '13:28')
    assert.are.same(result:to_string(), '13:28')

    result = Duration.parse('1d 2h 5min')
    assert.are.same(result:to_string('HH:MM'), '26:05')
    assert.are.same(result:to_string(), '1d 2:05')

    result = Duration.parse('2y4m2w3d15h25min')
    assert.are.same(result:to_string('HH:MM'), '20823:25')
    assert.are.same(result:to_string(), '2y 4m 2w 3d 15:25')

    result = Duration.parse('2y 4m 2w 3d 15h 42min')
    assert.are.same(result:to_string('HH:MM'), '20823:42')
    assert.are.same(result:to_string(), '2y 4m 2w 3d 15:42')
  end)
end)

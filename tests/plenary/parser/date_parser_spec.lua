local DateParser = require('orgmode.parser.date')
local Date = require('orgmode.objects.date')

describe('Date parser', function()
  it('should parse single date from line', function()
    local line = 'This is some line and has a date <2021-05-15 Sat> that is active'
    local dates = DateParser.parse_all_from_line(line, 1)
    assert.are.same(1, #dates)
    assert.are.same({
        type = 'NONE',
        date = Date.from_string('2021-05-15 Sat'),
        active = true,
        range = {
          from = { line = 1, col = 34 },
          to = { line = 1, col = 49 }
        },
        valid = true,
    }, dates[1])
  end)

  it('should parse multiple dates from line', function()
    local line = 'This is some line and has a date <2021-05-15 Sat> that is active and has a date [2021-06-15 Tue 09:00] that is inactive'
    local dates = DateParser.parse_all_from_line(line, 1)
    assert.are.same(2, #dates)
    assert.are.same({
        type = 'NONE',
        date = Date.from_string('2021-05-15 Sat'),
        active = true,
        range = {
          from = { line = 1, col = 34 },
          to = { line = 1, col = 49 }
        },
        valid = true,
    }, dates[1])
    assert.are.same({
        type = 'NONE',
        date = Date.from_string('2021-06-15 Tue 09:00'),
        active = false,
        range = {
          from = { line = 1, col = 81 },
          to = { line = 1, col = 102 }
        },
        valid = true,
    }, dates[2])
  end)

  it('should parse multiple dates from line and setup proper range with same dates', function()
    local line = 'This is some line and has a date <2021-05-15 Sat> and again has the same date <2021-05-15 Sat> for no reason'
    local dates = DateParser.parse_all_from_line(line, 1)
    assert.are.same(2, #dates)
    assert.are.same({
        type = 'NONE',
        date = Date.from_string('2021-05-15 Sat'),
        active = true,
        range = {
          from = { line = 1, col = 34 },
          to = { line = 1, col = 49 }
        },
        valid = true,
    }, dates[1])
    assert.are.same({
        type = 'NONE',
        date = Date.from_string('2021-05-15 Sat'),
        active = true,
        range = {
          from = { line = 1, col = 79 },
          to = { line = 1, col = 94 }
        },
        valid = true,
    }, dates[2])
  end)
end)

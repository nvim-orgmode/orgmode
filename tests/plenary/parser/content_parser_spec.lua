local Content = require('orgmode.parser.content')
local Types = require('orgmode.parser.types')
local Date = require('orgmode.objects.date')
local Range = require('orgmode.parser.range')

describe('Content parser', function()
  it('should parse plain text', function()
    local content = Content:new({
      line = 'Some plain text',
      lnum = 1,
      parent = { id = 0, level = 0 },
    })
    assert.are.same(Types.CONTENT, content.type)
    assert.are.same('Some plain text', content.line)
    assert.are.same({}, content.dates)
    assert.are.same({ id = 0, level = 0 }, content.parent)
    assert.are.same(0, content.level)
    assert.are.same(1, content.id)
  end)

  it('should parse keyword', function()
    local content = Content:new({
      line = ' #+FILETAGS: :Tag1:Tag2:',
      lnum = 1,
      parent = { id = 0, level = 0 },
    })
    assert.are.same(Types.KEYWORD, content.type)
    assert.is.True(content:is_keyword())
  end)

  it('should parse planning', function()
    local content = Content:new({
      line = 'DEADLINE: <2021-05-15 Sat> SCHEDULED: <2021-05-12 Wed 13:30 +1w> CLOSED: <2021-05-16 Sun 15:45>',
      lnum = 1,
      parent = { id = 0, level = 0 },
    })
    assert.are.same(Types.PLANNING, content.type)
    assert.are.same({
      Date.from_string('2021-05-15 Sat', {
        type = 'DEADLINE',
        active = true,
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 11,
          end_col = 26,
        })
      }),
      Date.from_string('2021-05-12 Wed 13:30 +1w', {
        type = 'SCHEDULED',
        active = true,
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 39,
          end_col = 64,
        })
      }),
      Date.from_string('2021-05-16 Sun 15:45', {
        type = 'CLOSED',
        active = true,
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 74,
          end_col = 95,
        })
      })
    }, content.dates)
  end)

  it('should not do any parsing on commented lines', function()
    local content = Content:new({
      line = '# DEADLINE: <2021-05-15 Sat> SCHEDULED: <2021-05-12 Wed 13:30 +1w> CLOSED: <2021-05-16 Sun 15:45>',
      lnum = 1,
      parent = { id = 0, level = 0 },
    })
    assert.are.same(Types.CONTENT, content.type)
    assert.are.same('# DEADLINE: <2021-05-15 Sat> SCHEDULED: <2021-05-12 Wed 13:30 +1w> CLOSED: <2021-05-16 Sun 15:45>', content.line)
    assert.are.same({}, content.dates)
    assert.are.same({ id = 0, level = 0 }, content.parent)
    assert.are.same(0, content.level)
    assert.are.same(1, content.id)
  end)
end)

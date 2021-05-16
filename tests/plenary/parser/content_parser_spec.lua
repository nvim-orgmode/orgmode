local Content = require('orgmode.parser.content')
local Types = require('orgmode.parser.types')
local Date = require('orgmode.objects.date')

describe('Content parser', function()
  it('should parse plain text', function()
    local content = Content:new({
      line = 'Some plain text',
      lnum = 1,
      parent = { id = 0, level = 0 },
    })
    assert.are.same(Types.CONTENT, content.type)
    assert.are.same('Some plain text', content.line)
    assert.are.same(0, content.parent)
    assert.are.same(0, content.level)
    assert.are.same(1, content.id)
  end)

  it('should parse keyword', function()
    local content = Content:new({
      line = ' #+FILETAGS: Tag1, Tag2',
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
      {
        type = 'DEADLINE',
        date = Date.from_string('2021-05-15 Sat'),
        active = true,
        range = {
          from = { line = 1, col = 11 },
          to = { line = 1, col = 26 }
        },
        valid = true,
      },
      {
        type = 'SCHEDULED',
        date = Date.from_string('2021-05-12 Wed 13:30 +1w'),
        active = true,
        range = {
          from = { line = 1, col = 39 },
          to = { line = 1, col = 64 }
        },
        valid = true,
      },
      {
        type = 'CLOSED',
        date = Date.from_string('2021-05-16 Sun 15:45'),
        active = true,
        range = {
          from = { line = 1, col = 74 },
          to = { line = 1, col = 95 }
        },
        valid = true,
      }
    }, content.dates)
  end)
end)

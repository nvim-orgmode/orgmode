local Headline = require('orgmode.parser.headline')
local Range = require('orgmode.parser.range')
local Date = require('orgmode.objects.date')

describe('Headline parser', function()
  it('should parse todo keyword and tags', function()
    local headline = Headline:new({
      line = '* TODO [#A] This is some content :WORK:PROJECT:',
      lnum = 1,
      parent = { id = 0 },
    })
    assert.are.same({ id = 0 }, headline.parent)
    assert.are.same(1, headline.level)
    assert.are.same(1, headline.id)
    assert.are.same('* TODO [#A] This is some content :WORK:PROJECT:', headline.line)
    assert.are.same('TODO', headline.todo_keyword.value)
    assert.are.same({'WORK', 'PROJECT'}, headline.tags)
    assert.are.same('A', headline.priority)
    assert.are.same({}, headline.dates)
    assert.are.same('[#A] This is some content', headline.title)
    assert.are.same(Range.from_line(1), headline.range)
    assert.are.same(false, headline:is_archived())
  end)

  it('should parse dates', function()
    local headline = Headline:new({
      line = '* TODO [#B] This is some content with date <2021-05-20 Thu> and datetime [2021-06-20 Sun 14:30] :WORK:PROJECT:',
      lnum = 1,
      parent = { id = 0 },
    })
    assert.are.same({ id = 0 }, headline.parent)
    assert.are.same(1, headline.level)
    assert.are.same(1, headline.id)
    assert.are.same('* TODO [#B] This is some content with date <2021-05-20 Thu> and datetime [2021-06-20 Sun 14:30] :WORK:PROJECT:', headline.line)
    assert.are.same('TODO', headline.todo_keyword.value)
    assert.are.same({'WORK', 'PROJECT'}, headline.tags)
    assert.are.same('B', headline.priority)
    assert.are.same({
      Date.from_string('2021-05-20 Thu', {
        type = 'NONE',
        active = true,
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 44,
          end_col = 59,
        })
      }),
      Date.from_string('2021-06-20 Sun 14:30', {
        type = 'NONE',
        active = false,
        range = Range:new({
          start_line = 1,
          end_line = 1,
          start_col = 74,
          end_col = 95,
        })
      }),
    }, headline.dates)
    assert.are.same(Range.from_line(1), headline.range)
  end)

  it('should accept archived flag', function()
    local headline = Headline:new({
      line = '* TODO [#A] This is some content :WORK:PROJECT:',
      lnum = 1,
      parent = { id = 0 },
      archived = true
    })
    assert.are.same({ id = 0 }, headline.parent)
    assert.are.same(1, headline.level)
    assert.are.same(1, headline.id)
    assert.are.same('* TODO [#A] This is some content :WORK:PROJECT:', headline.line)
    assert.are.same('TODO', headline.todo_keyword.value)
    assert.are.same({'WORK', 'PROJECT'}, headline.tags)
    assert.are.same('A', headline.priority)
    assert.are.same({}, headline.dates)
    assert.are.same('[#A] This is some content', headline.title)
    assert.are.same(Range.from_line(1), headline.range)
    assert.are.same(true, headline:is_archived())
  end)
end)

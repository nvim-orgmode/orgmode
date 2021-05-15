local Headline = require('orgmode.parser.headline')

describe('Headline parser', function()
  it('should parse todo keyword and tags', function()
    local headline = Headline:new({
      line = '* TODO [#A] This is some content :WORK:PROJECT:',
      lnum = 1,
      parent = { id = 0 },
    })
    assert.are.same(0, headline.parent)
    assert.are.same(1, headline.level)
    assert.are.same(1, headline.id)
    assert.are.same('* TODO [#A] This is some content :WORK:PROJECT:', headline.line)
    assert.are.same('TODO', headline.todo_keyword)
    assert.are.same({'WORK', 'PROJECT'}, headline.tags)
    assert.are.same('A', headline.priority)
    assert.are.same('This is some content', headline.title)
    assert.are.same({
      from = { line = 1, col = 1},
      to = { line = 1, col = 1},
    }, headline.range)
  end)
end)

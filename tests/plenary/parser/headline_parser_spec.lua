local Headline = require('orgmode.parser.headline')

describe('Headline parser', function()
  it('should parse todo keyword and tags', function()
    local headline = Headline:new({
      line = '* TODO [#A] This is some content :WORK:PROJECT:',
      line_nr = 1,
      parent = { line_nr = 0 },
    })
    assert.are.same(headline.todo_keyword, 'TODO')
    assert.are.same(headline.tags, {'WORK', 'PROJECT'})
    assert.are.same(headline.priority, 'A')
    assert.are.same(headline.title, 'This is some content')
  end)
end)

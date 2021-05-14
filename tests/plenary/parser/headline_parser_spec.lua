local Headline = require('orgmode.parser.headline')

describe('Headline parser', function()
  it('should parse and tokenize headline content', function()
    local headline = Headline:new({
      line = '* TODO This is some content :WORK:PROJECT:',
      line_nr = 1,
      parent = { line_nr = 0 },
    })
    assert.are.same(headline.todo_keyword, 'TODO')
    assert.are.same(headline.tags, {'WORK', 'PROJECT'})
  end)
end)

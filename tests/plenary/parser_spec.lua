local parser = require('orgmode.parser')
describe('Parser', function()
  it('should parse lines', function()
    local lines = {
      '* TODO Test orgmode',
      '** TODO Test orgmode level 2',
      'Some content for level 2',
      '*** TODO Level 3',
      'Content Level 3',
      '* TODO top level todo',
      'content for top level todo',
    }

    local parsed = parser.parse(lines)
    assert.are.same(parsed.headlines[1].line, '* TODO Test orgmode')
    assert.are.same(parsed.headlines[1].level, 1)
    assert.are.same(parsed.headlines[1].parent, parsed)
    assert.are.same(parsed.headlines[1].headlines[1].line, '** TODO Test orgmode level 2')
    assert.are.same(parsed.headlines[1].headlines[1].level, 2)
    assert.are.same(parsed.headlines[1].headlines[1].parent, parsed.headlines[1])
    assert.are.same(parsed.headlines[1].headlines[1].content[1].line, 'Some content for level 2')
    assert.are.same(parsed.headlines[1].headlines[1].content[1].parent, parsed.headlines[1].headlines[1])
    assert.are.same(parsed.headlines[1].headlines[1].headlines[1].line, '*** TODO Level 3')
    assert.are.same(parsed.headlines[1].headlines[1].headlines[1].level, 3)
    assert.are.same(parsed.headlines[1].headlines[1].headlines[1].parent, parsed.headlines[1].headlines[1])
    assert.are.same(parsed.headlines[1].headlines[1].headlines[1].content[1].line, 'Content Level 3')
    assert.are.same(parsed.headlines[1].headlines[1].headlines[1].content[1].parent, parsed.headlines[1].headlines[1].headlines[1])
    assert.are.same(parsed.headlines[2].line, '* TODO top level todo')
    assert.are.same(parsed.headlines[2].level, 1)
    assert.are.same(parsed.headlines[2].parent, parsed)
    assert.are.same(parsed.headlines[2].content[1].line, 'content for top level todo')
    assert.are.same(parsed.headlines[2].content[1].parent, parsed.headlines[2])
  end)
end)

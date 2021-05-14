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
    assert.are.same(parsed.content[1], { content = {}, headlines = { 2 }, level = 1, line = "* TODO Test orgmode", line_nr = 1, parent = 0, type = "HEADLINE" })
    assert.are.same(parsed.content[2], { content = { 3 }, headlines = { 4 }, level = 2, line = "** TODO Test orgmode level 2", line_nr = 2, parent = 1, type = "HEADLINE" })
    assert.are.same(parsed.content[3], { level = 2, line = "Some content for level 2", line_nr = 3, parent = 2, type = "CONTENT" })
    assert.are.same(parsed.content[4], { content = { 5 }, headlines = {}, level = 3, line = "*** TODO Level 3", line_nr = 4, parent = 2, type = "HEADLINE" })
    assert.are.same(parsed.content[5], { level = 3, line = "Content Level 3", line_nr = 5, parent = 4, type = "CONTENT" })
    assert.are.same(parsed.content[6], { content = { 7 }, headlines = {}, level = 1, line = "* TODO top level todo", line_nr = 6, parent = 1, type = "HEADLINE" })
    assert.are.same(parsed.content[7], { level = 1, line = "content for top level todo", line_nr = 7, parent = 6, type = "CONTENT" })
    assert.are.same(parsed.level, 0)
    assert.are.same(parsed.line_nr, 0)
    assert.are.same(parsed.lines, lines)
  end)
end)

local parser = require('orgmode.parser')
describe('Parser', function()
  it('should parse lines', function()
    local lines = {
      '* TODO Test orgmode',
      '** TODO Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* DONE top level todo with multiple tags :OFFICE:PROJECT:',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '* NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:',
    }

    local parsed = parser.parse(lines)
    assert.are.same({
      content = {},
      headlines = { 2 },
      level = 1,
      line = "* TODO Test orgmode",
      line_nr = 1,
      parent = 0,
      type = "HEADLINE",
      todo_keyword = 'TODO',
      tags = {},
    }, parsed.content[1])
    assert.are.same({
      content = { 3 },
      headlines = { 4 },
      level = 2,
      line = "** TODO Test orgmode level 2 :PRIVATE:",
      line_nr = 2,
      parent = 1,
      type = "HEADLINE",
      todo_keyword = 'TODO',
      tags = {'PRIVATE'},
    }, parsed.content[2])
    assert.are.same({
      level = 2,
      line = "Some content for level 2",
      line_nr = 3,
      parent = 2,
      type = "CONTENT",
    }, parsed.content[3])
    assert.are.same({
      content = { 5 },
      headlines = {},
      level = 3,
      line = "*** NEXT Level 3",
      line_nr = 4,
      parent = 2,
      type = "HEADLINE",
      todo_keyword = 'NEXT',
      tags = {},
    }, parsed.content[4])
    assert.are.same({
      level = 3,
      line = "Content Level 3",
      line_nr = 5,
      parent = 4,
      type = "CONTENT",
    }, parsed.content[5])
    assert.are.same({
      content = { 7 },
      headlines = {},
      level = 1,
      line = "* DONE top level todo :WORK:",
      line_nr = 6,
      parent = 0,
      type = "HEADLINE",
      todo_keyword = 'DONE',
      tags = {'WORK'},
    }, parsed.content[6])
    assert.are.same({
      level = 1,
      line = "content for top level todo",
      line_nr = 7,
      parent = 6,
      type = "CONTENT",
    }, parsed.content[7])
    assert.are.same({
      content = { 9 },
      headlines = {},
      level = 1,
      line = "* DONE top level todo with multiple tags :OFFICE:PROJECT:",
      line_nr = 8,
      parent = 0,
      type = "HEADLINE",
      todo_keyword = 'DONE',
      tags = {'OFFICE', 'PROJECT'},
    }, parsed.content[8])
    assert.are.same({
      level = 1,
      line = "multiple tags content, tags not read from content :FROMCONTENT:",
      line_nr = 9,
      parent = 8,
      type = "CONTENT",
    }, parsed.content[9])
    assert.are.same({
      content = {},
      headlines = {},
      level = 1,
      line = "* NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:",
      line_nr = 10,
      parent = 0,
      type = "HEADLINE",
      todo_keyword = '',
      tags = {},
    }, parsed.content[10])
    assert.are.same(parsed.level, 0)
    assert.are.same(parsed.line_nr, 0)
    assert.are.same(parsed.lines, lines)
  end)
end)

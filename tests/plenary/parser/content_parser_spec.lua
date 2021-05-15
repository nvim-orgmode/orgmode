local Content = require('orgmode.parser.content')
local Types = require('orgmode.parser.types')

describe('Content parser', function()
  it('should parse plain text', function()
    local content = Content:new({
      line = 'Some plain text',
      lnum = 1,
      parent = { id = 0, level = 0 },
    })
    assert.are.same(content.type, Types.CONTENT)
    assert.are.same(content.line, 'Some plain text')
    assert.are.same(content.parent, 0)
    assert.are.same(content.level, 0)
    assert.are.same(content.id, 1)
  end)

  it('should parse keyword', function()
    local content = Content:new({
      line = ' #+FILETAGS: Tag1, Tag2',
      lnum = 1,
      parent = { id = 0, level = 0 },
    })
    assert.are.same(content.type, Types.KEYWORD)
    assert.is.True(content:is_keyword())
  end)
end)

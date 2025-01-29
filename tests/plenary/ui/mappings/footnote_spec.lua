local helpers = require('tests.plenary.helpers')

describe('footnotes', function()
  local file_content = {
    '* Headline',
    'This is footnote reference [fn:footref] here',
    '',
    '* Foo',
    'This is a second footnote reference [fn:second]',
    '* Bar',
    'Bar content',
    '* Footnotes',
    '[fn:footref] This is the footnote',
  }

  it('should jump to footnote from footnote reference', function()
    helpers.create_file(file_content)

    vim.fn.cursor(2, 29)
    vim.cmd([[norm ,oo]])
    assert.are.same({ 9, 1 }, { vim.fn.line('.'), vim.fn.col('.') })
  end)

  it('should jump to footnote from footnote reference', function()
    helpers.create_file(file_content)

    vim.fn.cursor(9, 1)
    vim.cmd([[norm ,oo]])
    assert.are.same({ 2, 28 }, { vim.fn.line('.'), vim.fn.col('.') })
  end)

  it('should prompt to create a footnote from footnote reference', function()
    helpers.create_file(file_content)
    vim.fn.cursor(5, 38)
    vim.cmd([[norm ,oothe second footnote]])
    assert.are.same({
      '* Headline',
      'This is footnote reference [fn:footref] here',
      '',
      '* Foo',
      'This is a second footnote reference [fn:second]',
      '* Bar',
      'Bar content',
      '* Footnotes',
      '[fn:second] the second footnote',
      '[fn:footref] This is the footnote',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should not do anything if it cannot find the footnote reference from footnote', function()
    local content = vim.list_extend(file_content, { '[fn:third] the third footnote' })
    helpers.create_file(content)
    vim.fn.cursor(10, 1)
    vim.cmd([[norm ,oo]])
    assert.are.same(content, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.are.same({ 10, 1 }, { vim.fn.line('.'), vim.fn.col('.') })
  end)
end)

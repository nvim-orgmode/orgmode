local helpers = require('tests.plenary.ui.helpers')

describe('Heading mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should toggle the current line into a headline and vice versa', function()
    helpers.load_file_content({
      'top level line',
      '* top level heading',
      '  simple line',
      '  - list item',
      '  * [ ] unfinished checkbox item',
      '  - [X] finished checkbox item',
    })

    assert.are.same('top level line', vim.fn.getline(1))
    assert.are.same('  simple line', vim.fn.getline(3))
    assert.are.same('  - list item', vim.fn.getline(4))
    assert.are.same('  * [ ] unfinished checkbox item', vim.fn.getline(5))
    assert.are.same('  - [X] finished checkbox item', vim.fn.getline(6))

    vim.fn.cursor(1, 1)
    vim.cmd([[norm ,o*]])
    assert.are.same('* top level line', vim.fn.getline(1))
    vim.cmd([[norm ,o*]])
    assert.are.same('top level line', vim.fn.getline(1))

    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,o*]])
    assert.are.same('** simple line', vim.fn.getline(3))
    vim.cmd([[norm ,o*]])
    assert.are.same('simple line', vim.fn.getline(3))

    vim.fn.cursor(4, 1)
    vim.cmd([[norm ,o*]])
    assert.are.same('** list item', vim.fn.getline(4))
    vim.cmd([[norm ,o*]])
    assert.are.same('list item', vim.fn.getline(4))

    vim.fn.cursor(5, 1)
    vim.cmd([[norm ,o*]])
    assert.are.same('** TODO unfinished checkbox item', vim.fn.getline(5))
    vim.cmd([[norm ,o*]])
    assert.are.same('TODO unfinished checkbox item', vim.fn.getline(5))

    vim.fn.cursor(6, 1)
    vim.cmd([[norm ,o*]])
    assert.are.same('** DONE finished checkbox item', vim.fn.getline(6))
    vim.cmd([[norm ,o*]])
    assert.are.same('DONE finished checkbox item', vim.fn.getline(6))
  end)

  it('should demote the heading (org_do_demote)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-07 Tue 12:00 +1w>',
      '',
      '* TODO Another task',
    })
    vim.fn.cursor(3, 1)
    assert.are.same('* TODO Test orgmode', vim.fn.getline('.'))
    vim.cmd([[norm >>]])
    assert.are.same('** TODO Test orgmode', vim.fn.getline('.'))
  end)

  it('should demote the heading and its subtree (org_demote_subtree)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '',
      '* TODO Another task',
    })

    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
    }, vim.api.nvim_buf_get_lines(0, 2, 8, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm >s]])
    assert.are.same({
      '** TODO Test orgmode',
      '   DEADLINE: <2021-07-21 Wed 22:02>',
      '*** TODO [#A] Test orgmode level 2 :PRIVATE:',
      ' Some content for level 2',
      '**** NEXT [#1] Level 3',
      ' Content Level 3',
    }, vim.api.nvim_buf_get_lines(0, 2, 8, false))

    -- Support count
    vim.cmd([[norm 4>s]])
    assert.are.same({
      '****** TODO Test orgmode',
      '       DEADLINE: <2021-07-21 Wed 22:02>',
      '******* TODO [#A] Test orgmode level 2 :PRIVATE:',
      '     Some content for level 2',
      '******** NEXT [#1] Level 3',
      '     Content Level 3',
    }, vim.api.nvim_buf_get_lines(0, 2, 8, false))
  end)

  it('should promote the heading (org_do_promote)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
    })

    vim.fn.cursor(5, 1)
    assert.are.same('** TODO [#A] Test orgmode level 2 :PRIVATE:', vim.fn.getline('.'))
    vim.cmd([[norm <<]])
    assert.are.same(
      '* TODO [#A] Test orgmode level 2                                       :PRIVATE:',
      vim.fn.getline('.')
    )
  end)

  it('should promote the heading and its subtree (org_promote_subtree)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '',
      '* TODO Another task',
    })

    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
    }, vim.api.nvim_buf_get_lines(0, 2, 8, false))
    vim.fn.cursor(5, 1)
    vim.cmd([[norm <s]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '* TODO [#A] Test orgmode level 2                                       :PRIVATE:',
      'Some content for level 2',
      '** NEXT [#1] Level 3',
      'Content Level 3',
    }, vim.api.nvim_buf_get_lines(0, 2, 8, false))

    helpers.load_file_content({
      '***** TODO Test orgmode',
      '      DEADLINE: <2021-07-21 Wed 22:02>',
      '****** TODO [#A] Test orgmode level 2 :PRIVATE:',
      '       Some content for level 2',
      '******* NEXT [#1] Level 3',
      '        Content Level 3',
    }, vim.api.nvim_buf_get_lines(0, 0, 6, false))
    vim.fn.cursor(1, 1)

    -- Support count
    vim.cmd([[norm 2<s]])
    assert.are.same({
      '*** TODO Test orgmode',
      '    DEADLINE: <2021-07-21 Wed 22:02>',
      '**** TODO [#A] Test orgmode level 2 :PRIVATE:',
      '     Some content for level 2',
      '***** NEXT [#1] Level 3',
      '      Content Level 3',
    }, vim.api.nvim_buf_get_lines(0, 0, 6, false))

    -- Handle overflow
    vim.cmd([[norm 5<s]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      '   Some content for level 2',
      '*** NEXT [#1] Level 3',
      '    Content Level 3',
    }, vim.api.nvim_buf_get_lines(0, 0, 6, false))
  end)
end)

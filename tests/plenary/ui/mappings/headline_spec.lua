local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')

describe('Heading mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should toggle the current line into a headline and vice versa', function()
    helpers.create_file({
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
    helpers.create_file({
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
    helpers.create_file({
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
    local check
    if config.org_adapt_indentation then
      check = {
        '** TODO Test orgmode',
        '   DEADLINE: <2021-07-21 Wed 22:02>',
        '*** TODO [#A] Test orgmode level 2 :PRIVATE:',
        ' Some content for level 2',
        '**** NEXT [#1] Level 3',
        ' Content Level 3',
      }
    else
      check = {
        '** TODO Test orgmode',
        'DEADLINE: <2021-07-21 Wed 22:02>',
        '*** TODO [#A] Test orgmode level 2 :PRIVATE:',
        'Some content for level 2',
        '**** NEXT [#1] Level 3',
        'Content Level 3',
      }
    end
    vim.cmd([[norm >s]])
    assert.are.same(check, vim.api.nvim_buf_get_lines(0, 2, 8, false))

    -- Support count
    local check
    if config.org_adapt_indentation then
      check = {
        '****** TODO Test orgmode',
        '       DEADLINE: <2021-07-21 Wed 22:02>',
        '******* TODO [#A] Test orgmode level 2 :PRIVATE:',
        '     Some content for level 2',
        '******** NEXT [#1] Level 3',
        '     Content Level 3',
      }
    else
      check = {
        '****** TODO Test orgmode',
        'DEADLINE: <2021-07-21 Wed 22:02>',
        '******* TODO [#A] Test orgmode level 2 :PRIVATE:',
        'Some content for level 2',
        '******** NEXT [#1] Level 3',
        'Content Level 3',
      }
    end
    vim.cmd([[norm 4>s]])
    assert.are.same(check, vim.api.nvim_buf_get_lines(0, 2, 8, false))
  end)

  it('should promote the heading (org_do_promote)', function()
    helpers.create_file({
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
    helpers.create_file({
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

    helpers.create_file({
      '***** TODO Test orgmode',
      '      DEADLINE: <2021-07-21 Wed 22:02>',
      '****** TODO [#A] Test orgmode level 2 :PRIVATE:',
      '       Some content for level 2',
      '******* NEXT [#1] Level 3',
      '        Content Level 3',
    })
    vim.fn.cursor(1, 1)

    -- Support count
    local check
    if config.org_adapt_indentation then
      check = {
        '*** TODO Test orgmode',
        '    DEADLINE: <2021-07-21 Wed 22:02>',
        '**** TODO [#A] Test orgmode level 2 :PRIVATE:',
        '     Some content for level 2',
        '***** NEXT [#1] Level 3',
        '      Content Level 3',
      }
    else
      check = {
        '*** TODO Test orgmode',
        'DEADLINE: <2021-07-21 Wed 22:02>',
        '**** TODO [#A] Test orgmode level 2 :PRIVATE:',
        'Some content for level 2',
        '***** NEXT [#1] Level 3',
        'Content Level 3',
      }
    end
    vim.cmd([[norm 2<s]])
    assert.are.same(check, vim.api.nvim_buf_get_lines(0, 0, 6, false))

    -- Handle overflow
    local check
    if config.org_adapt_indentation then
      check = {
        '* TODO Test orgmode',
        '  DEADLINE: <2021-07-21 Wed 22:02>',
        '** TODO [#A] Test orgmode level 2 :PRIVATE:',
        '   Some content for level 2',
        '*** NEXT [#1] Level 3',
        '    Content Level 3',
      }
    else
      check = {
        '* TODO Test orgmode',
        'DEADLINE: <2021-07-21 Wed 22:02>',
        '** TODO [#A] Test orgmode level 2 :PRIVATE:',
        'Some content for level 2',
        '*** NEXT [#1] Level 3',
        'Content Level 3',
      }
    end
    vim.cmd([[norm 5<s]])
    assert.are.same(check, vim.api.nvim_buf_get_lines(0, 0, 6, false))
  end)

  it('should promote line to (TODO) heading', function()
    helpers.create_file({ 'foobar' })
    vim.fn.cursor(1, 1)
    vim.cmd([[norm ,oiT]])
    assert.are.same({
      '* TODO foobar',
    }, vim.api.nvim_buf_get_lines(0, 0, 2, false))

    helpers.create_file({ 'foobar' })
    vim.fn.cursor(1, 1)
    vim.cmd([[norm ,oit]])
    assert.are.same({
      '* TODO foobar',
    }, vim.api.nvim_buf_get_lines(0, 0, 2, false))

    helpers.create_file({ 'foobar' })
    vim.fn.cursor(1, 1)
    vim.cmd([[norm ,oih]])
    assert.are.same({
      '* foobar',
    }, vim.api.nvim_buf_get_lines(0, 0, 2, false))
  end)

  it('should promote line left of the cursor to (TODO) heading', function()
    helpers.create_file({ 'foobar' })
    vim.fn.cursor(1, 4)
    vim.cmd([[norm ,oiT]])
    assert.are.same({
      'foo',
      '* TODO bar',
    }, vim.api.nvim_buf_get_lines(0, 0, 2, false))

    helpers.create_file({ 'foobar' })
    vim.fn.cursor(1, 4)
    vim.cmd([[norm ,oit]])
    assert.are.same({
      'foo',
      '* TODO bar',
    }, vim.api.nvim_buf_get_lines(0, 0, 2, false))

    helpers.create_file({ 'foobar' })
    vim.fn.cursor(1, 4)
    vim.cmd([[norm ,oih]])
    assert.are.same({
      'foo',
      '* bar',
    }, vim.api.nvim_buf_get_lines(0, 0, 2, false))
  end)

  it('should move subtree up (org_move_subtree_up)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
    })

    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
    }, vim.api.nvim_buf_get_lines(0, 2, 11, false))
    vim.fn.cursor(9, 1)
    vim.cmd([[norm ,oK]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
    }, vim.api.nvim_buf_get_lines(0, 2, 11, false))
  end)

  it('should move subtree down (org_move_subtree_down)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
    })

    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
    }, vim.api.nvim_buf_get_lines(0, 2, 18, false))
    vim.fn.cursor(9, 1)
    vim.cmd([[norm ,oJ]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
      '* DONE top level todo :WORK:',
      'content for top level todo',
    }, vim.api.nvim_buf_get_lines(0, 2, 18, false))
  end)

  it('should jump to next heading on any level (org_next_visible_heading)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
    })

    vim.cmd([[norm gg]])
    assert.are.same(1, vim.fn.line('.'))
    vim.cmd([[norm }]])
    assert.are.same(3, vim.fn.line('.'))
    vim.cmd([[norm }]])
    assert.are.same(5, vim.fn.line('.'))
    vim.cmd([[norm }]])
    assert.are.same(7, vim.fn.line('.'))
    vim.cmd([[norm }]])
    assert.are.same(9, vim.fn.line('.'))
    vim.cmd([[norm }]])
    assert.are.same(11, vim.fn.line('.'))
    vim.cmd([[norm }]])
    assert.are.same(16, vim.fn.line('.'))
  end)

  it('should jump to previous heading on any level (org_previous_visible_heading)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
    })

    vim.cmd([[norm G]])
    assert.are.same(18, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(16, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(11, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(9, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(7, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(5, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(3, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(3, vim.fn.line('.'))
  end)

  it('should jump to next heading on same level (org_backward_heading_same_level)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
      '* TODO Last Item',
    })

    vim.fn.cursor(3, 1)
    vim.cmd('norm ]]')
    assert.are.same(9, vim.fn.line('.'))
    vim.cmd('norm ]]')
    assert.are.same(11, vim.fn.line('.'))
    vim.cmd('norm ]]')
    assert.are.same(19, vim.fn.line('.'))
  end)

  it('should jump to previous heading on same level (org_backward_heading_same_level)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
      '* TODO Last Item',
    })

    vim.cmd([[norm G]])
    assert.are.same(19, vim.fn.line('.'))
    vim.cmd('norm [[')
    assert.are.same(11, vim.fn.line('.'))
    vim.cmd('norm [[')
    assert.are.same(9, vim.fn.line('.'))
    vim.cmd('norm [[')
    assert.are.same(3, vim.fn.line('.'))
  end)

  it('should walk up to parent headline (outline_up_heading)', function()
    helpers.create_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
    })

    vim.fn.cursor(7, 1)
    vim.cmd('norm g{')
    assert.are.same(5, vim.fn.line('.'))
    vim.cmd('norm g{')
    assert.are.same(3, vim.fn.line('.'))
  end)
end)

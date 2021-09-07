local helpers = require('tests.plenary.ui.helpers')
local Date = require('orgmode.objects.date')

describe('Mappings', function()
  before_each(function()
    helpers.load_file('tests/plenary/fixtures/todo.org')
  end)
  after_each(function()
    vim.cmd([[bw!]])
  end)

  it('should increase the date by 1 day (org_increase_date)', function()
    vim.fn.cursor(4, 21)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-22 Thu 22:02>', vim.fn.getline('.'))
  end)

  it('should decrease the date by 1 day (org_decrease_date)', function()
    vim.fn.cursor(4, 21)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-20 Tue 22:02>', vim.fn.getline('.'))
  end)

  it('should change todo state of a headline forward (org_todo)', function()
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      4,
      false
    ))
    vim.fn.cursor(3, 1)

    -- Changing to DONE and adding closed date
    vim.cmd([[norm cit]])
    assert.are.same({
      '* DONE Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02> CLOSED: [' .. Date.now():to_string() .. ']',
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      4,
      false
    ))

    -- Removing todo keyword and removing closed date
    vim.cmd([[norm cit]])
    assert.are.same({
      '* Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      4,
      false
    ))

    -- Setting TODO keyword, initial state
    vim.cmd([[norm cit]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      4,
      false
    ))
  end)

  it('should change todo state of a headline backward (org_todo_prev)', function()
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      4,
      false
    ))
    vim.fn.cursor(3, 1)

    -- Removing todo keyword
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      4,
      false
    ))

    -- Changing to DONE and adding closed date
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* DONE Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02> CLOSED: [' .. Date.now():to_string() .. ']',
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      4,
      false
    ))

    -- Setting TODO keyword, initial state
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      4,
      false
    ))
  end)

  it('should change todo state of repeatable task and add last repeat property and state change (org_todo)', function()
    assert.are.same({
      '* TODO Repeatable task',
      '  DEADLINE: <2021-09-07 Tue 12:00 +1w>',
      '* NOKEYWORD Headline with wrong todo keyword and wrong tag format :WORK : OFFICE:',
      '  - Regular item',
      '  - Second recular item',
      '    - Neste item',
    }, vim.api.nvim_buf_get_lines(
      0,
      18,
      24,
      false
    ))
    vim.fn.cursor(19, 1)
    vim.cmd([[norm cit]])
    assert.are.same({
      '* TODO Repeatable task',
      '  DEADLINE: <2021-09-14 Tue 12:00 +1w>',
      '  :PROPERTIES:',
      '  :LAST_REPEAT: [' .. Date.now():to_string() .. ']',
      '  :END:',
      '  - State "DONE" from "TODO" [' .. Date.now():to_string() .. ']',
    }, vim.api.nvim_buf_get_lines(
      0,
      18,
      24,
      false
    ))
  end)

  it('should toggle the checkbox state (org_toggle_checkbox)', function()
    assert.are.same('  - [ ] The checkbox', vim.fn.getline(12))
    assert.are.same('  - [X] The checkbox 2', vim.fn.getline(13))
    vim.fn.cursor(12, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('  - [X] The checkbox', vim.fn.getline(12))
    vim.fn.cursor(13, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('  - [ ] The checkbox 2', vim.fn.getline(13))
  end)

  it('should toggle archive tag on headline (org_toggle_archive_tag)', function()
    assert.are.same('* TODO Test orgmode', vim.fn.getline(3))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,oA]])
    assert.are.same(
      '* TODO Test orgmode                                                             :ARCHIVE:',
      vim.fn.getline(3)
    )
  end)

  it('should demote the heading (org_do_demote)', function()
    vim.fn.cursor(3, 1)
    assert.are.same('* TODO Test orgmode', vim.fn.getline('.'))
    vim.cmd([[norm >>]])
    assert.are.same('** TODO Test orgmode', vim.fn.getline('.'))
  end)

  it('should demote the heading and its subtree (org_demote_subtree)', function()
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      8,
      false
    ))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm >s]])
    assert.are.same({
      '** TODO Test orgmode',
      '   DEADLINE: <2021-07-21 Wed 22:02>',
      '*** TODO [#A] Test orgmode level 2 :PRIVATE:',
      ' Some content for level 2',
      '**** NEXT [#1] Level 3',
      ' Content Level 3',
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      8,
      false
    ))
  end)

  it('should promote the heading (org_do_promote)', function()
    vim.fn.cursor(5, 1)
    assert.are.same('** TODO [#A] Test orgmode level 2 :PRIVATE:', vim.fn.getline('.'))
    vim.cmd([[norm <<]])
    assert.are.same('* TODO [#A] Test orgmode level 2 :PRIVATE:', vim.fn.getline('.'))
  end)

  it('should promote the heading and its subtree (org_promote_subtree)', function()
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      8,
      false
    ))
    vim.fn.cursor(5, 1)
    vim.cmd([[norm <s]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '* TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '** NEXT [#1] Level 3',
      'Content Level 3',
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      8,
      false
    ))
  end)

  it('should add list item with Enter (org_meta_return)', function()
    assert.are.same({
      '  - Regular item',
      '  - Second recular item',
      '    - Neste item',
    }, vim.api.nvim_buf_get_lines(
      0,
      21,
      24,
      false
    ))
    vim.fn.cursor(22, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  - Regular item',
      '  - ',
      '  - Second recular item',
      '    - Neste item',
    }, vim.api.nvim_buf_get_lines(
      0,
      21,
      25,
      false
    ))
  end)

  it('should add headline with Enter (org_meta_return)', function()
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
    }, vim.api.nvim_buf_get_lines(
      0,
      8,
      12,
      false
    ))
    vim.fn.cursor(9, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      '',
      '* ',
      'content for top level todo',
    }, vim.api.nvim_buf_get_lines(
      0,
      8,
      12,
      false
    ))
  end)

  it('should add checkbox item with Enter (org_meta_return)', function()
    assert.are.same({
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
    }, vim.api.nvim_buf_get_lines(
      0,
      11,
      14,
      false
    ))
    vim.fn.cursor(12, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  - [ ] The checkbox',
      '  - [ ] ',
      '  - [X] The checkbox 2',
    }, vim.api.nvim_buf_get_lines(
      0,
      11,
      14,
      false
    ))
  end)

  it('should add numbered list item', function()
    assert.are.same({
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
      '* TODO Repeatable task',
    }, vim.api.nvim_buf_get_lines(
      0,
      15,
      19,
      false
    ))
    vim.fn.cursor(18, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
      '   3. ',
      '* TODO Repeatable task',
    }, vim.api.nvim_buf_get_lines(
      0,
      15,
      20,
      false
    ))
  end)

  it('should insert new heading after current subtree (org_insert_heading_respect_content)', function()
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    }, vim.api.nvim_buf_get_lines(
      0,
      8,
      15,
      false
    ))
    vim.fn.cursor(10, 1)
    vim.cmd([[norm ,oih]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '',
      '* ',
      '',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
    }, vim.api.nvim_buf_get_lines(
      0,
      8,
      15,
      false
    ))
  end)

  it('should insert new todo heading after current one (org_insert_todo_heading)', function()
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    }, vim.api.nvim_buf_get_lines(
      0,
      8,
      15,
      false
    ))
    vim.fn.cursor(9, 1)
    vim.cmd([[norm ,oiT]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      '',
      '* TODO ',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
    }, vim.api.nvim_buf_get_lines(
      0,
      8,
      15,
      false
    ))
  end)

  it('should insert new todo heading after current subtree (org_insert_todo_heading_respect_content)', function()
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    }, vim.api.nvim_buf_get_lines(
      0,
      8,
      15,
      false
    ))
    vim.fn.cursor(9, 1)
    vim.cmd([[norm ,oit]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '',
      '* TODO ',
      '',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
    }, vim.api.nvim_buf_get_lines(
      0,
      8,
      15,
      false
    ))
  end)

  it('should move subtree up (org_move_subtree_up)', function()
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
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      11,
      false
    ))
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
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      11,
      false
    ))
  end)

  it('should move subtree down (org_move_subtree_down)', function()
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
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      18,
      false
    ))
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
    }, vim.api.nvim_buf_get_lines(
      0,
      2,
      18,
      false
    ))
  end)

  it('should jump to next heading on any level (org_next_visible_heading)', function()
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
    vim.cmd([[norm G]])
    assert.are.same(24, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(21, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(19, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(16, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(11, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(9, vim.fn.line('.'))
    vim.cmd([[norm {]])
    assert.are.same(7, vim.fn.line('.'))
  end)

  it('should jump to previous heading on same level (org_backward_heading_same_level)', function()
    vim.cmd([[norm G]])
    assert.are.same(24, vim.fn.line('.'))
    vim.cmd('norm [[')
    assert.are.same(19, vim.fn.line('.'))
    vim.cmd('norm [[')
    assert.are.same(11, vim.fn.line('.'))
    vim.cmd('norm [[')
    assert.are.same(9, vim.fn.line('.'))
    vim.cmd('norm [[')
    assert.are.same(3, vim.fn.line('.'))
  end)

  it('should walk up to parent headline (outline_up_heading)', function()
    vim.fn.cursor(7, 1)
    vim.cmd('norm g{')
    assert.are.same(5, vim.fn.line('.'))
    vim.cmd('norm g{')
    assert.are.same(3, vim.fn.line('.'))
  end)
end)

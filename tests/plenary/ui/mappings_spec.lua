local helpers = require('tests.plenary.ui.helpers')
local config = require('orgmode.config')
local Date = require('orgmode.objects.date')

describe('Mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should increase the date by provided number of days (org_timestamp_up_day)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 21)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<S-UP>"]])
    assert.are.same('  DEADLINE: <2021-07-22 Thu 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 5\<S-UP>"]])
    assert.are.same('  DEADLINE: <2021-07-27 Tue 22:02>', vim.fn.getline('.'))
  end)

  it('should decrease the date by provided number of days (org_timestamp_down_day)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 21)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<S-DOWN>"]])
    assert.are.same('  DEADLINE: <2021-07-20 Tue 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 5\<S-DOWN>"]])
    assert.are.same('  DEADLINE: <2021-07-15 Thu 22:02>', vim.fn.getline('.'))
  end)

  it('should increase year part of the date (org_timestamp_up)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 15)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2022-07-21 Thu 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-a>"]])
    assert.are.same('  DEADLINE: <2026-07-21 Tue 22:02>', vim.fn.getline('.'))
  end)

  it('should increase month part of the date (org_timestamp_up)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 20)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2021-08-21 Sat 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-a>"]])
    assert.are.same('  DEADLINE: <2021-12-21 Tue 22:02>', vim.fn.getline('.'))
  end)

  it('should increase day part of the date (org_timestamp_up)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 22)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-22 Thu 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-26 Mon 22:02>', vim.fn.getline('.'))
  end)

  it('should increase hour part of the date (org_timestamp_up)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 29)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 23:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-22 Thu 03:02>', vim.fn.getline('.'))
  end)

  it('should increase minute part of the date (org_timestamp_up)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 32)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:07>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:27>', vim.fn.getline('.'))
  end)

  it('should toggle active/inactive state of date (org_timestamp_up)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 13)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: [2021-07-21 Wed 22:02]', vim.fn.getline('.'))
    vim.fn.cursor(4, 34)
    vim.cmd([[exe "norm \<C-a>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
  end)

  it('should decrease year part of the date (org_timestamp_down)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 15)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-x>"]])
    assert.are.same('  DEADLINE: <2020-07-21 Tue 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-x>"]])
    assert.are.same('  DEADLINE: <2016-07-21 Thu 22:02>', vim.fn.getline('.'))
  end)

  it('should decrease month part of the date (org_timestamp_down)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 20)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-x>"]])
    assert.are.same('  DEADLINE: <2021-06-21 Mon 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-x>"]])
    assert.are.same('  DEADLINE: <2021-02-21 Sun 22:02>', vim.fn.getline('.'))
  end)

  it('should decrease day part of the date (org_timestamp_down)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 22)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-20 Tue 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-16 Fri 22:02>', vim.fn.getline('.'))
  end)

  it('should decrease hour part of the date (org_timestamp_down)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 29)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 21:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 17:02>', vim.fn.getline('.'))
  end)

  it('should decrease minute part of the date (org_timestamp_down)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(4, 32)
    assert.are.same('  DEADLINE: <2021-07-21 Wed 22:02>', vim.fn.getline('.'))
    vim.cmd([[exe "norm \<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 21:57>', vim.fn.getline('.'))
    vim.cmd([[exe "norm 4\<C-x>"]])
    assert.are.same('  DEADLINE: <2021-07-21 Wed 21:37>', vim.fn.getline('.'))
  end)

  it('should change todo state of a headline forward (org_todo)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
    vim.fn.cursor(3, 1)

    -- Changing to DONE and adding closed date
    vim.cmd([[norm cit]])
    assert.are.same({
      '* DONE Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02> CLOSED: [' .. Date.now():to_string() .. ']',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    -- Removing todo keyword and removing closed date
    vim.cmd([[norm cit]])
    assert.are.same({
      '* Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    -- Setting TODO keyword, initial state
    vim.cmd([[norm cit]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
  end)

  it('should change todo state of a headline backward (org_todo_prev)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })

    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
    vim.fn.cursor(3, 1)

    -- Removing todo keyword
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    -- Changing to DONE and adding closed date
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* DONE Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02> CLOSED: [' .. Date.now():to_string() .. ']',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))

    -- Setting TODO keyword, initial state
    vim.cmd([[norm ciT]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    }, vim.api.nvim_buf_get_lines(0, 2, 4, false))
  end)

  it('should change todo state of repeatable task and add last repeat property and state change (org_todo)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-07 Tue 12:00 +1w>',
      '',
      '* TODO Another task',
    })

    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-07 Tue 12:00 +1w>',
      '',
      '* TODO Another task',
    }, vim.api.nvim_buf_get_lines(0, 2, 6, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm cit]])
    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-14 Tue 12:00 +1w>',
      '  :PROPERTIES:',
      '  :LAST_REPEAT: [' .. Date.now():to_string() .. ']',
      '  :END:',
      '  - State "DONE" from "TODO" [' .. Date.now():to_string() .. ']',
      '',
      '* TODO Another task',
    }, vim.api.nvim_buf_get_lines(0, 2, 10, false))
  end)

  it('should toggle the checkbox state (org_toggle_checkbox)', function()
    helpers.load_file_content({
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
    })

    assert.are.same('  - [ ] The checkbox', vim.fn.getline(2))
    assert.are.same('  - [X] The checkbox 2', vim.fn.getline(3))
    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('  - [X] The checkbox', vim.fn.getline(2))
    vim.fn.cursor(3, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('  - [ ] The checkbox 2', vim.fn.getline(3))
  end)

  it('should toggle archive tag on headline (org_toggle_archive_tag)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-09-07 Tue 12:00 +1w>',
      '',
      '* TODO Another task',
    })
    assert.are.same('* TODO Test orgmode', vim.fn.getline(3))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,oA]])
    assert.are.same(
      '* TODO Test orgmode                                                             :ARCHIVE:',
      vim.fn.getline(3)
    )
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
    assert.are.same('* TODO [#A] Test orgmode level 2 :PRIVATE:', vim.fn.getline('.'))
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
      '* TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '** NEXT [#1] Level 3',
      'Content Level 3',
    }, vim.api.nvim_buf_get_lines(0, 2, 8, false))
  end)

  it('should add list item with Enter (org_meta_return)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  - Regular item',
      '  - Second recular item',
      '    - Neste item',
    })

    assert.are.same({
      '  - Regular item',
      '  - Second recular item',
      '    - Neste item',
    }, vim.api.nvim_buf_get_lines(0, 3, 6, false))
    vim.fn.cursor(4, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  - Regular item',
      '  - ',
      '  - Second recular item',
      '    - Neste item',
    }, vim.api.nvim_buf_get_lines(0, 3, 7, false))
  end)

  it('should add list item with blank line with Enter (org_meta_return)', function()
    config:extend({
      org_blank_before_new_entry = {
        heading = true,
        plain_list_item = true,
      },
    })
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  - Regular item',
      '  - Second recular item',
      '    - Neste item',
    })

    assert.are.same({
      '  - Regular item',
      '  - Second recular item',
      '    - Neste item',
    }, vim.api.nvim_buf_get_lines(0, 3, 6, false))
    vim.fn.cursor(4, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  - Regular item',
      '',
      '  - ',
      '  - Second recular item',
      '    - Neste item',
    }, vim.api.nvim_buf_get_lines(0, 3, 8, false))
    config:extend({
      org_blank_before_new_entry = {
        heading = true,
        plain_list_item = false,
      },
    })
  end)

  it('should add headline with Enter (org_meta_return)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
    })

    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
    }, vim.api.nvim_buf_get_lines(0, 2, 6, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      '',
      '* ',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
    }, vim.api.nvim_buf_get_lines(0, 2, 8, false))
  end)

  it('should add headline with Enter without the blank line (org_meta_return)', function()
    config:extend({
      org_blank_before_new_entry = { heading = false, plain_list_item = false },
    })
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
    })

    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
    }, vim.api.nvim_buf_get_lines(0, 2, 6, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      '* ',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
    }, vim.api.nvim_buf_get_lines(0, 2, 7, false))
    config:extend({
      org_blank_before_new_entry = { heading = true, plain_list_item = false },
    })
  end)

  it('should add headline with Enter right after the current headline (org_meta_return)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
    })

    assert.are.same({
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
    }, vim.api.nvim_buf_get_lines(0, 2, 9, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '* TODO Test orgmode',
      '',
      '* ',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
      '* DONE top level todo :WORK:',
    }, vim.api.nvim_buf_get_lines(0, 2, 11, false))
  end)

  it('should add checkbox item with Enter (org_meta_return)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
    })

    assert.are.same({
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
    }, vim.api.nvim_buf_get_lines(0, 3, 6, false))
    vim.fn.cursor(4, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  - [ ] The checkbox',
      '  - [ ] ',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
    }, vim.api.nvim_buf_get_lines(0, 3, 7, false))
  end)

  it('should add a list item after a multiline list item with Enter (org_meta_return)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  - this list item',
      '    spans more than',
      '    one line',
    })

    assert.are.same({
      '  - this list item',
      '    spans more than',
      '    one line',
    }, vim.api.nvim_buf_get_lines(0, 3, 6, false))
    vim.fn.cursor(4, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  - this list item',
      '    spans more than',
      '    one line',
      '  - ',
    }, vim.api.nvim_buf_get_lines(0, 3, 7, false))
  end)

  it(
    'should add a list item with Enter after a multiline list item from anywhere in the list item (org_meta_return)',
    function()
      helpers.load_file_content({
        '#TITLE: Test',
        '',
        '* TODO Test orgmode',
        '  - this list item',
        '    spans more than',
        '    one line',
      })

      assert.are.same({
        '  - this list item',
        '    spans more than',
        '    one line',
      }, vim.api.nvim_buf_get_lines(0, 3, 6, false))
      vim.fn.cursor(6, 1)
      vim.cmd([[exe "norm ,\<CR>"]])
      assert.are.same({
        '  - this list item',
        '    spans more than',
        '    one line',
        '  - ',
      }, vim.api.nvim_buf_get_lines(0, 3, 7, false))
    end
  )

  it('should add a list item with Enter from the description of the list item (org_meta_return)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  - description :: item',
    })

    assert.are.same({
      '  - description :: item',
    }, vim.api.nvim_buf_get_lines(0, 3, 4, false))
    vim.fn.cursor(4, 8)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  - description :: item',
      '  - ',
    }, vim.api.nvim_buf_get_lines(0, 3, 5, false))
  end)

  it(
    'should add a list item with Enter when the cursor is between the bullet and the item (org_meta_return)',
    function()
      helpers.load_file_content({
        '#TITLE: Test',
        '',
        '* TODO Test orgmode',
        '  - item',
      })

      assert.are.same({
        '  - item',
      }, vim.api.nvim_buf_get_lines(0, 3, 4, false))
      vim.fn.cursor(4, 4)
      vim.cmd([[exe "norm ,\<CR>"]])
      assert.are.same({
        '  - item',
        '  - ',
      }, vim.api.nvim_buf_get_lines(0, 3, 5, false))
    end
  )

  it('should add a list item with Enter skipping over any nested content (org_meta_return)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    })

    assert.are.same({
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    }, vim.api.nvim_buf_get_lines(0, 4, 7, false))
    vim.fn.cursor(5, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      '  - [ ] ',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    }, vim.api.nvim_buf_get_lines(0, 4, 8, false))
  end)

  it('should add numbered list item', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
      '* TODO Repeatable task',
    })

    assert.are.same({
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
      '* TODO Repeatable task',
    }, vim.api.nvim_buf_get_lines(0, 7, 11, false))
    vim.fn.cursor(10, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
      '   3. ',
      '* TODO Repeatable task',
    }, vim.api.nvim_buf_get_lines(0, 7, 12, false))
  end)

  it('should add numbered list item in the middle of the list', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
      '* TODO Repeatable task',
    })

    assert.are.same({
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
      '* TODO Repeatable task',
    }, vim.api.nvim_buf_get_lines(0, 7, 11, false))
    vim.fn.cursor(9, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '** NEXT Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. ',
      '   3. Second item',
      '* TODO Repeatable task',
    }, vim.api.nvim_buf_get_lines(0, 7, 12, false))
  end)

  it('should insert new heading after current subtree (org_insert_heading_respect_content)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    })
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    }, vim.api.nvim_buf_get_lines(0, 2, 10, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,oih]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '',
      '* ',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
    }, vim.api.nvim_buf_get_lines(0, 2, 9, false))
  end)

  it(
    'should insert new heading after current subtree without the blank line (org_insert_heading_respect_content)',
    function()
      config:extend({
        org_blank_before_new_entry = { heading = false, plain_list_item = false },
      })
      helpers.load_file_content({
        '#TITLE: Test',
        '',
        '* DONE top level todo :WORK:',
        'content for top level todo',
        '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
        '  - [ ] The checkbox',
        '  - [X] The checkbox 2',
        '    - [ ] Nested checkbox',
        'multiple tags content, tags not read from content :FROMCONTENT:',
      })
      assert.are.same({
        '* DONE top level todo :WORK:',
        'content for top level todo',
        '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
        '  - [ ] The checkbox',
        '  - [X] The checkbox 2',
        '    - [ ] Nested checkbox',
        'multiple tags content, tags not read from content :FROMCONTENT:',
      }, vim.api.nvim_buf_get_lines(0, 2, 10, false))
      vim.fn.cursor(3, 1)
      vim.cmd([[norm ,oih]])
      assert.are.same({
        '* DONE top level todo :WORK:',
        'content for top level todo',
        '* ',
        '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
        '  - [ ] The checkbox',
        '  - [X] The checkbox 2',
      }, vim.api.nvim_buf_get_lines(0, 2, 8, false))
      config:extend({
        org_blank_before_new_entry = { heading = true, plain_list_item = false },
      })
    end
  )

  it('should insert new todo heading after current one (org_insert_todo_heading)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    })

    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    }, vim.api.nvim_buf_get_lines(0, 2, 10, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,oiT]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      '',
      '* TODO ',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
    }, vim.api.nvim_buf_get_lines(0, 2, 10, false))
  end)

  it('should insert new todo heading after current one without the blank line (org_insert_todo_heading)', function()
    config:extend({
      org_blank_before_new_entry = { heading = false, plain_list_item = false },
    })
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    })

    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    }, vim.api.nvim_buf_get_lines(0, 2, 10, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,oiT]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      '* TODO ',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
    }, vim.api.nvim_buf_get_lines(0, 2, 9, false))
    config:extend({
      org_blank_before_new_entry = { heading = true, plain_list_item = false },
    })
  end)

  it('should insert new todo heading after current subtree (org_insert_todo_heading_respect_content)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    })
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
      '    - [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    }, vim.api.nvim_buf_get_lines(0, 2, 10, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,oit]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '',
      '* TODO ',
      '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
      '  - [ ] The checkbox',
      '  - [X] The checkbox 2',
    }, vim.api.nvim_buf_get_lines(0, 2, 9, false))
  end)

  it(
    'should insert new todo heading after current subtree without the blank line (org_insert_todo_heading_respect_content)',
    function()
      config:extend({
        org_blank_before_new_entry = { heading = false, plain_list_item = false },
      })
      helpers.load_file_content({
        '#TITLE: Test',
        '',
        '* DONE top level todo :WORK:',
        'content for top level todo',
        '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
        '  - [ ] The checkbox',
        '  - [X] The checkbox 2',
        '    - [ ] Nested checkbox',
        'multiple tags content, tags not read from content :FROMCONTENT:',
      })
      assert.are.same({
        '* DONE top level todo :WORK:',
        'content for top level todo',
        '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
        '  - [ ] The checkbox',
        '  - [X] The checkbox 2',
        '    - [ ] Nested checkbox',
        'multiple tags content, tags not read from content :FROMCONTENT:',
      }, vim.api.nvim_buf_get_lines(0, 2, 10, false))
      vim.fn.cursor(3, 1)
      vim.cmd([[norm ,oit]])
      assert.are.same({
        '* DONE top level todo :WORK:',
        'content for top level todo',
        '* TODO ',
        '* TODO top level todo with multiple tags :OFFICE:PROJECT:',
        '  - [ ] The checkbox',
        '  - [X] The checkbox 2',
      }, vim.api.nvim_buf_get_lines(0, 2, 8, false))
      config:extend({
        org_blank_before_new_entry = { heading = true, plain_list_item = false },
      })
    end
  )

  it('should move subtree up (org_move_subtree_up)', function()
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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

  it('should add/update deadline date for a headline (org_deadline)', function()
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

    vim.fn.cursor(6, 1)
    -- Set to today
    vim.cmd('norm ,oid')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('   DEADLINE: <' .. Date.today():to_string() .. '>', vim.fn.getline(6))

    -- Increase by one day
    vim.fn.cursor(6, 16)
    vim.cmd([[exe "norm \<S-UP>"]])
    assert.are.same('   DEADLINE: <' .. Date.today():add({ day = 1 }):to_string() .. '>', vim.fn.getline(6))

    -- Update back to today
    vim.fn.cursor(7, 1)
    vim.cmd('norm ,oid.')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('   DEADLINE: <' .. Date.today():to_string() .. '>', vim.fn.getline(6))
  end)

  it('should add/update schedule date for a headline (org_schedule)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      '  DEADLINE: <2021-09-15 Wed 22:02>',
      'Some content for level 2',
      '*** NEXT [#1] Level 3',
      'Content Level 3',
    })

    vim.fn.cursor(6, 1)
    -- Set to today
    vim.cmd('norm ,ois')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same(
      '  DEADLINE: <2021-09-15 Wed 22:02> SCHEDULED: <' .. Date.today():to_string() .. '>',
      vim.fn.getline(6)
    )

    -- Increase by one day
    vim.fn.cursor(6, 51)
    vim.cmd([[exe "norm \<S-UP>"]])
    assert.are.same(
      '  DEADLINE: <2021-09-15 Wed 22:02> SCHEDULED: <' .. Date.today():add({ day = 1 }):to_string() .. '>',
      vim.fn.getline(6)
    )
    --
    -- Update back to today
    vim.fn.cursor(7, 1)
    vim.cmd('norm ,ois.')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same(
      '  DEADLINE: <2021-09-15 Wed 22:02> SCHEDULED: <' .. Date.today():to_string() .. '>',
      vim.fn.getline(6)
    )
  end)

  it('should insert plain timestamp under cursor (org_time_stamp)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '',
      '*** NEXT [#1] Level 3',
    })
    vim.fn.cursor(7, 1)
    vim.cmd('norm ,oi.')
    vim.cmd([[exe "norm \<CR>"]])
    -- date inserted
    assert.are.same('<' .. Date.today():to_string() .. '>', vim.fn.getline(7))
    -- increase by 1 day
    vim.cmd([[exe "norm \<S-UP>"]])
    assert.are.same('<' .. Date.today():add({ day = 1 }):to_string() .. '>', vim.fn.getline(7))
    -- make sure it updated back to todays date by opening the calendar and pressing . to go to today's date
    vim.cmd('norm ,oi..')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('<' .. Date.today():to_string() .. '>', vim.fn.getline(7))
  end)

  it('should append an end date range when plain timestamp is added right after another date', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '<2021-09-16 Thu> ',
      '*** NEXT [#1] Level 3',
    })
    vim.fn.cursor(7, 17)
    vim.cmd('norm ,oi.')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('<2021-09-16 Thu>--<' .. Date.today():to_string() .. '> ', vim.fn.getline(7))
  end)

  it('should insert plain inactive timestamp under cursor (org_time_stamp)', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '',
      '*** NEXT [#1] Level 3',
    })
    vim.fn.cursor(7, 1)
    vim.cmd('norm ,oi!')
    vim.cmd([[exe "norm \<CR>"]])
    -- date inserted
    assert.are.same('[' .. Date.today():to_string() .. ']', vim.fn.getline(7))
    -- increase by 1 day
    vim.cmd([[exe "norm \<S-UP>"]])
    assert.are.same('[' .. Date.today():add({ day = 1 }):to_string() .. ']', vim.fn.getline(7))
    -- make sure it updated back to todays date by opening the calendar and pressing . to go to today's date
    vim.cmd('norm ,oi!.')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('[' .. Date.today():to_string() .. ']', vim.fn.getline(7))
  end)

  it('should append an end date range when inactive plain timestamp is added right after another date', function()
    helpers.load_file_content({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '** TODO [#A] Test orgmode level 2 :PRIVATE:',
      'Some content for level 2',
      '[2021-09-16 Thu] ',
      '*** NEXT [#1] Level 3',
    })
    vim.fn.cursor(7, 17)
    vim.cmd('norm ,oi!')
    vim.cmd([[exe "norm \<CR>"]])
    assert.are.same('[2021-09-16 Thu]--[' .. Date.today():to_string() .. '] ', vim.fn.getline(7))
  end)

  it('should increase the priority of the current headline', function()
    helpers.load_file_content({
      '* TODO [#B] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO [#B] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ciR')
    assert.are.same('* TODO [#A] Test orgmode', vim.fn.getline(1))
  end)

  it('should decrease the priority of the current headline', function()
    helpers.load_file_content({
      '* TODO [#B] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO [#B] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm cir')
    assert.are.same('* TODO [#C] Test orgmode', vim.fn.getline(1))
  end)

  it('should set the priority based on the input key', function()
    helpers.load_file_content({
      '* TODO [#B] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO [#B] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ,o,a\r')
    assert.are.same('* TODO [#A] Test orgmode', vim.fn.getline(1))
  end)

  it('should remove the priority if <Space> is pressed', function()
    helpers.load_file_content({
      '* TODO [#B] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO [#B] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ,o, \r')
    assert.are.same('* TODO Test orgmode', vim.fn.getline(1))
  end)

  it('should add a priority if the item does not already have one', function()
    helpers.load_file_content({
      '* TODO Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ,o,a\r')
    assert.are.same('* TODO [#A] Test orgmode', vim.fn.getline(1))
  end)

  it('should add a priority if the item has no todo keyword', function()
    helpers.load_file_content({
      '* Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ,o,a\r')
    assert.are.same('* [#A] Test orgmode', vim.fn.getline(1))
  end)
end)

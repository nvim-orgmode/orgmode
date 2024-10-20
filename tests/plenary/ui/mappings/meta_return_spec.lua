local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')

describe('Meta return mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should add list item with Enter (org_meta_return)', function()
    helpers.create_agenda_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  - Regular item',
      '  - Second regular item',
      '    - Nested item',
      '  - [x] Checkbox item',
      '  - [x] Second checkbox item',
      '    - [x] Nested checkbox item',
    })

    assert.are.same({
      '  - Regular item',
      '  - Second regular item',
      '    - Nested item',
      '  - [x] Checkbox item',
      '  - [x] Second checkbox item',
      '    - [x] Nested checkbox item',
    }, vim.api.nvim_buf_get_lines(0, 3, 9, false))

    -- test for plain list item
    vim.fn.cursor(4, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  - Regular item',
      '  - ',
      '  - Second regular item',
      '    - Nested item',
      '  - [x] Checkbox item',
      '  - [x] Second checkbox item',
      '    - [x] Nested checkbox item',
    }, vim.api.nvim_buf_get_lines(0, 3, 10, false))

    -- tests for checkbox item
    vim.fn.cursor(8, 7) -- on the opening bracket
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  - Regular item',
      '  - ',
      '  - Second regular item',
      '    - Nested item',
      '  - [x] Checkbox item',
      '  - [ ] ',
      '  - [x] Second checkbox item',
      '    - [x] Nested checkbox item',
    }, vim.api.nvim_buf_get_lines(0, 3, 11, false))
    vim.fn.cursor(8, 8) -- on the 'x' (a.k.a. status)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  - Regular item',
      '  - ',
      '  - Second regular item',
      '    - Nested item',
      '  - [x] Checkbox item',
      '  - [ ] ',
      '  - [ ] ',
      '  - [x] Second checkbox item',
      '    - [x] Nested checkbox item',
    }, vim.api.nvim_buf_get_lines(0, 3, 12, false))
  end)

  it('should add list item with blank line with Enter (org_meta_return)', function()
    config:extend({
      org_blank_before_new_entry = {
        heading = true,
        plain_list_item = true,
      },
    })
    helpers.create_agenda_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  - Regular item',
      '  - Second regular item',
      '    - Nested item',
    })

    assert.are.same({
      '  - Regular item',
      '  - Second regular item',
      '    - Nested item',
    }, vim.api.nvim_buf_get_lines(0, 3, 6, false))
    vim.fn.cursor(4, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  - Regular item',
      '',
      '  - ',
      '  - Second regular item',
      '    - Nested item',
    }, vim.api.nvim_buf_get_lines(0, 3, 8, false))
    config:extend({
      org_blank_before_new_entry = {
        heading = true,
        plain_list_item = false,
      },
    })
  end)

  it('should add headline with Enter (org_meta_return)', function()
    helpers.create_agenda_file({
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
    helpers.create_agenda_file({
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
    helpers.create_agenda_file({
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
    helpers.create_agenda_file({
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
    helpers.create_agenda_file({
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
      helpers.create_agenda_file({
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

  it(
    'should add a list item with Enter after a multiline list item from anywhere in the list item (org_meta_return)',
    function()
      helpers.create_agenda_file({
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
    helpers.create_agenda_file({
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
      helpers.create_agenda_file({
        '#TITLE: Test',
        '',
        '* TODO Test orgmode',
        '  * item',
      })

      assert.are.same({
        '  * item',
      }, vim.api.nvim_buf_get_lines(0, 3, 4, false))
      vim.fn.cursor(4, 4)
      vim.cmd([[exe "norm ,\<CR>"]])
      assert.are.same({
        '  * item',
        '  * ',
      }, vim.api.nvim_buf_get_lines(0, 3, 5, false))
    end
  )

  it('should add a list item with Enter skipping over any nested content (org_meta_return)', function()
    helpers.create_agenda_file({
      '#TITLE: Test',
      '',
      '* TODO Test orgmode',
      '  * [ ] The checkbox',
      '  * [X] The checkbox 2',
      '    * [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    })

    assert.are.same({
      '  * [X] The checkbox 2',
      '    * [ ] Nested checkbox',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    }, vim.api.nvim_buf_get_lines(0, 4, 7, false))
    vim.fn.cursor(5, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '  * [X] The checkbox 2',
      '    * [ ] Nested checkbox',
      '  * [ ] ',
      'multiple tags content, tags not read from content :FROMCONTENT:',
    }, vim.api.nvim_buf_get_lines(0, 4, 8, false))
  end)

  it('should add numbered list item (org_meta_return)', function()
    helpers.create_agenda_file({
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

  it('should add numbered list item in the middle of the list (org_meta_return)', function()
    helpers.create_agenda_file({
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

  it('should add numbered list at the end of the file (org_meta_return)', function()
    helpers.create_agenda_file({
      '* TODO Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. Second item',
    })

    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm ,\<CR>"]])
    assert.are.same({
      '* TODO Working on this now :OFFICE:NESTED:',
      '   1. First item',
      '   2. ',
      '   3. Second item',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it(
    'should add list item with Enter in insert mode if org_return_uses_meta_return is enabled and cursor is at the end',
    function()
      helpers.create_agenda_file({
        '#TITLE: Test',
        '',
        '* TODO Test orgmode',
        '  - Regular item',
        '  - Second regular item',
        '    - Nested item',
        '  - [x] Checkbox item',
        '  - [x] Second checkbox item',
        '    - [x] Nested checkbox item',
      }, {
        mappings = {
          org_return_uses_meta_return = true,
        },
      })
      vim.fn.cursor(4, 16)
      vim.cmd([[exe "norm a\<CR>"]])
      assert.are.same({
        '  - Regular item',
        '  - ',
        '  - Second regular item',
        '    - Nested item',
        '  - [x] Checkbox item',
        '  - [x] Second checkbox item',
        '    - [x] Nested checkbox item',
      }, vim.api.nvim_buf_get_lines(0, 3, 10, false))
    end
  )

  it(
    'should not add list item with Enter in insert mode if org_return_uses_meta_return is enabled and cursor is not at the end',
    function()
      helpers.create_agenda_file({
        '#TITLE: Test',
        '',
        '* TODO Test orgmode',
        '  - Regular item',
        '  - Second regular item',
        '    - Nested item',
        '  - [x] Checkbox item',
        '  - [x] Second checkbox item',
        '    - [x] Nested checkbox item',
      }, {
        mappings = {
          org_return_uses_meta_return = true,
        },
      })
      vim.fn.cursor(4, 14)
      vim.cmd([[exe "norm a\<CR>"]])
      assert.are.same({
        '  - Regular it',
        '    em',
        '  - Second regular item',
        '    - Nested item',
        '  - [x] Checkbox item',
        '  - [x] Second checkbox item',
        '    - [x] Nested checkbox item',
      }, vim.api.nvim_buf_get_lines(0, 3, 10, false))
    end
  )
end)

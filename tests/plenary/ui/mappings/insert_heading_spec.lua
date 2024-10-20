local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')

describe('Insert heading mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should insert new heading after current subtree (org_insert_heading_respect_content)', function()
    helpers.create_file({
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
      helpers.create_file({
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

  it('should insert new todo heading in empty org file', function()
    helpers.create_file({ '' })
    vim.fn.cursor(1, 1)
    vim.cmd([[norm ,oiT]])
    assert.are.same({ '* TODO ' }, vim.api.nvim_buf_get_lines(0, 0, 2, false))

    helpers.create_file({ '' })
    vim.fn.cursor(1, 1)
    vim.cmd([[norm ,oit]])
    assert.are.same({ '* TODO ' }, vim.api.nvim_buf_get_lines(0, 0, 2, false))

    helpers.create_file({ '' })
    vim.fn.cursor(1, 1)
    vim.cmd([[norm ,oih]])
    assert.are.same({ '* ' }, vim.api.nvim_buf_get_lines(0, 0, 2, false))
  end)

  it('should insert new todo heading on root level', function()
    helpers.create_file({
      '',
      '* TODO heading',
    })

    vim.fn.cursor(1, 1)
    vim.cmd([[norm ,oiT]])
    assert.are.same({
      '* TODO ',
      '* TODO heading',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))

    helpers.create_file({
      '',
      '* TODO heading',
    })

    vim.fn.cursor(1, 1)
    vim.cmd([[norm ,oit]])
    assert.are.same({
      '* TODO ',
      '* TODO heading',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))

    helpers.create_file({
      '',
      '* TODO heading',
    })

    vim.fn.cursor(1, 1)
    vim.cmd([[norm ,oih]])
    assert.are.same({
      '* ',
      '* TODO heading',
    }, vim.api.nvim_buf_get_lines(0, 0, 3, false))
  end)

  it('should insert new todo heading after current one (org_insert_todo_heading)', function()
    helpers.create_file({
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
    helpers.create_file({
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
    helpers.create_file({
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
      helpers.create_file({
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
end)

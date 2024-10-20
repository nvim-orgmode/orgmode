local helpers = require('tests.plenary.helpers')

describe('Checkbox mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should toggle the checkbox state (org_toggle_checkbox)', function()
    helpers.create_file({
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

  it('should update the checklist cookies on a headline', function()
    helpers.create_file({
      '* Test orgmode [/]',
      '- [ ] checkbox item',
      '- [ ] checkbox item',
    })
    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('* Test orgmode [1/2]', vim.fn.getline(1))
  end)

  it('should update the checklist cookies on a parent list', function()
    helpers.create_file({
      '- Test orgmode [/]',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
    })
    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('- Test orgmode [1/2]', vim.fn.getline(1))
  end)

  it('should update the checklist cookies with a percentage within a headline', function()
    helpers.create_file({
      '* Test orgmode [%]',
      '- [ ] checkbox item',
      '- [ ] checkbox item',
    })
    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('* Test orgmode [50%]', vim.fn.getline(1))
  end)

  it('should update the checklist cookies with a percentage within a nested list', function()
    helpers.create_file({
      '- Test orgmode [%]',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
    })
    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('- Test orgmode [33%]', vim.fn.getline(1))
  end)

  it('should update the checklist cookies with when the cookie is not the first entry', function()
    helpers.create_file({
      '- Test orgmode',
      '- listitem with cookie [%]',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
    })
    vim.fn.cursor(3, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('- listitem with cookie [33%]', vim.fn.getline(2))
  end)

  it('should update the checklist cookies with when there are more than 9 items', function()
    helpers.create_file({
      '- Test orgmode [0/10]',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
    })
    vim.fn.cursor(3, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('- Test orgmode [1/10]', vim.fn.getline(1))
  end)

  it('should update nested cookies and checkboxes', function()
    helpers.create_file({
      '- [ ] Test orgmode [/]',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item [/]',
      '    - [ ] checkbox item',
      '    - [ ] checkbox item',
      '  - [ ] checkbox item',
    })
    vim.fn.cursor(4, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same({
      '- [ ] Test orgmode [0/3]',
      '  - [ ] checkbox item',
      '  - [-] checkbox item [1/2]',
      '    - [X] checkbox item',
      '    - [ ] checkbox item',
      '  - [ ] checkbox item',
    }, vim.api.nvim_buf_get_lines(0, 0, 6, false))
    vim.fn.cursor(5, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same({
      '- [-] Test orgmode [1/3]',
      '  - [ ] checkbox item',
      '  - [X] checkbox item [2/2]',
      '    - [X] checkbox item',
      '    - [X] checkbox item',
      '  - [ ] checkbox item',
    }, vim.api.nvim_buf_get_lines(0, 0, 6, false))
  end)

  it('should update headline cookies when updating checkboxes', function()
    helpers.create_file({
      '* Test orgmode [/]',
      '- [ ] checkbox item',
      '- [-] checkbox item [1/2]',
      '  - [ ] checkbox item',
      '  - [X] checkbox item',
      '- [ ] checkbox item',
    })
    vim.fn.cursor(4, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same({
      '* Test orgmode [1/3]',
      '- [ ] checkbox item',
      '- [X] checkbox item [2/2]',
      '  - [X] checkbox item',
      '  - [X] checkbox item',
      '- [ ] checkbox item',
    }, vim.api.nvim_buf_get_lines(0, 0, 6, false))
  end)
end)

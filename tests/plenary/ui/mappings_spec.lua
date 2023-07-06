local helpers = require('tests.plenary.ui.helpers')
local org = require('orgmode')
local config = require('orgmode.config')
local Files = require('orgmode.parser.files')

describe('Mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
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
      '* TODO Test orgmode                                                    :ARCHIVE:',
      vim.fn.getline(3)
    )
  end)

  it('should update the checklist cookies on a headline', function()
    helpers.load_file_content({
      '* Test orgmode [/]',
      '- [ ] checkbox item',
      '- [ ] checkbox item',
    })
    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('* Test orgmode [1/2]', vim.fn.getline(1))
  end)

  it('should update the checklist cookies on a parent list', function()
    helpers.load_file_content({
      '- Test orgmode [/]',
      '  - [ ] checkbox item',
      '  - [ ] checkbox item',
    })
    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('- Test orgmode [1/2]', vim.fn.getline(1))
  end)

  it('should update the checklist cookies with a percentage within a headline', function()
    helpers.load_file_content({
      '* Test orgmode [%]',
      '- [ ] checkbox item',
      '- [ ] checkbox item',
    })
    vim.fn.cursor(2, 1)
    vim.cmd([[exe "norm \<C-space>"]])
    assert.are.same('* Test orgmode [50%]', vim.fn.getline(1))
  end)

  it('should update the checklist cookies with a percentage within a nested list', function()
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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
    helpers.load_file_content({
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

  it('should follow link to given headline in given org file', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      ' - some',
      ' - boiler',
      ' - plate',
      '** target headline',
      '   - more',
      '   - boiler',
      '   - plate',
    })
    vim.cmd([[norm w]])
    helpers.load_file_content({
      string.format('This link should lead to [[file:%s::*target headline][target]]', target_path),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    assert.is.same('** target headline', vim.api.nvim_get_current_line())
  end)

  it('should follow link to headline of given custom_id in given org file', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      ' - some',
      ' - boiler',
      ' - plate',
      '** headline of target custom_id',
      '   :PROPERTIES:',
      '   :CUSTOM_ID: target',
      '   :END:',
      '   - more',
      '   - boiler',
      '   - plate',
    })
    vim.cmd([[norm w]])
    helpers.load_file_content({
      string.format('This link should lead to [[file:%s::#target][target]]', target_path),
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(1, 30)
    vim.cmd([[norm ,oo]])
    assert.is.same('** headline of target custom_id', vim.api.nvim_get_current_line())
  end)

  it('should follow link to headline of given custom_id in given org file', function()
    local target_path = helpers.load_file_content({
      '* Test hyperlink',
      '  an [[target][internal link]]',
      '  - some',
      '  - boiler',
      '  - plate',
      '** headline of a deticated anchor',
      '   - more',
      '   - boiler',
      '   - plate <<target>>',
    })
    vim.cmd([[norm w]])
    vim.fn.cursor(2, 30)
    assert.is.same('  an [[target][internal link]]', vim.api.nvim_get_current_line())
    vim.cmd([[norm ,oo]])
    assert.is.same('** headline of a deticated anchor', vim.api.nvim_get_current_line())
  end)

  it('should respect custom  mapping prefix', function()
    config:extend({
      mappings = {
        prefix = '<Leader>f',
      },
    })

    helpers.load_file_content({
      '* DONE top level todo :WORK:',
      'content for top level todo',
    })
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
    }, vim.api.nvim_buf_get_lines(0, 0, 2, false))
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,fit]])
    assert.are.same({
      '* DONE top level todo :WORK:',
      'content for top level todo',
      '',
      '* TODO ',
    }, vim.api.nvim_buf_get_lines(0, 0, 4, false))
  end)
end)

local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')

describe('Mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should toggle archive tag on headline (org_toggle_archive_tag)', function()
    helpers.create_file({
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

  it('should respect custom  mapping prefix', function()
    config:extend({
      mappings = {
        prefix = '<Leader>f',
      },
    })

    helpers.create_file({
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

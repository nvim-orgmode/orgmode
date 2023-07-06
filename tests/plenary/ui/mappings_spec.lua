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

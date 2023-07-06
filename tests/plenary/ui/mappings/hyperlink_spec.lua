local helpers = require('tests.plenary.ui.helpers')

describe('Hyperlink mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
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
end)

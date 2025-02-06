local helpers = require('tests.plenary.helpers')

describe('folding', function()
  it('works', function()
    helpers.create_file({
      '* First',
      '** Second',
      '*** Third',
      '**** Fourth',
      '***** Fifth',
      'text',
    })
    vim.cmd.normal({ 'GzM', bang = true })
    local foldlevel = vim.fn.foldlevel(6)
    assert.are.same(5, foldlevel)
  end)
end)

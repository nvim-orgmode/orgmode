local helpers = require('tests.plenary.ui.helpers')

describe('Checkbox mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
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
end)

local config = require('orgmode.config')
local helpers = require('tests.plenary.helpers')

describe('Edit special operation', function()
  local start_org_bufnr
  local expandtab = vim.opt.expandtab
  local edit_special_indent = config.org_edit_src_content_indentation

  local setup_test = function(o)
    helpers.create_file(o.lines)
    start_org_bufnr = vim.api.nvim_get_current_buf()
    vim.fn.cursor(unpack(o.startpos))

    if not o.noenter then
      vim.cmd([[norm ,o']])
      assert.are.same(o.ft, vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }))
      assert.Not.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())
    end
  end

  after_each(function()
    pcall(vim.api.nvim_buf_delete, start_org_bufnr, { force = true })
    vim.opt.expandtab = expandtab
    config.org_edit_src_content_indentation = edit_special_indent
  end)

  it('should only pull content from the src block into the edit special buffer', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 0

    local lines = {
      '* This is my source block',
      '#+BEGIN_SRC python',
      'import os',
      '',
      'print(os.uname())',
      '#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'python', startpos = { 3, 1 } })
    assert.are.same(vim.trim(lines[3]), vim.fn.getline('.'))

    assert.are.same({
      'import os',
      '',
      'print(os.uname())',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd([[norm gg]])
    assert.are.same('import os', vim.fn.getline('.'))
    vim.cmd([[norm 2dd]])

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    -- Leading indent configuration is applied
    assert.are.same({
      '* This is my source block',
      '#+BEGIN_SRC python',
      'print(os.uname())',
      '#+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should add lines from special buffer back to the source org buffer on special buffer wipeout', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 0

    local lines = {
      '* This is my source block',
      '#+BEGIN_SRC python',
      'import os',
      '',
      'print(os.uname())',
      '#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'python', startpos = { 3, 1 } })

    assert.are.same({
      'import os',
      '',
      'print(os.uname())',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    local newline = 'print(os.urandom())'
    vim.cmd(string.format('norm Go%s', newline))
    assert.are.same(newline, vim.fn.getline('.'))

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    -- Leading indent configuration is applied
    assert.are.same({
      '* This is my source block',
      '#+BEGIN_SRC python',
      'import os',
      '',
      'print(os.uname())',
      'print(os.urandom())',
      '#+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should remove lines removed in the special buffer from the source org buffer on wipeout', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 0

    local lines = {
      '* This is my source block',
      '#+BEGIN_SRC python',
      'import os',
      '',
      'print(os.uname())',
      '#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'python', startpos = { 3, 1 } })

    assert.are.same({
      'import os',
      '',
      'print(os.uname())',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd('norm ggdG')

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    -- Leading indent configuration is applied
    assert.are.same({
      '* This is my source block',
      '#+BEGIN_SRC python',
      '',
      '#+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should accept a src block match on the start edge of a src block definiton', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 0

    local lines = {
      '* This is my source block',
      '#+BEGIN_SRC python',
      'import os',
      '',
      'print(os.uname())',
      '#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ noenter = true, lines = lines, ft = 'python', startpos = { 2, 1 } })
    assert.are.same(vim.trim(lines[2]), vim.fn.getline('.'))

    vim.cmd("norm ,o'")
    assert.are_not.equal(start_org_bufnr, vim.api.nvim_get_current_buf())

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())
  end)

  it('should accept a src block match on the end edge of a src block definiton', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 0

    local lines = {
      '* This is my source block',
      '#+BEGIN_SRC python',
      'import os',
      '',
      'print(os.uname())',
      '#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ noenter = true, lines = lines, ft = 'python', startpos = { 6, 9999 } })
    assert.are.same(vim.trim(lines[6]), vim.fn.getline('.'))

    vim.cmd("norm ,o'")
    assert.are_not.equal(start_org_bufnr, vim.api.nvim_get_current_buf())

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())
  end)

  it('should not add leading space to empty lines from edit special buffer', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 0

    local lines = {
      '* This is my source block',
      '  #+BEGIN_SRC python',
      '  import os',
      '',
      '  print(os.uname())',
      '#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'python', startpos = { 3, 1 } })
    assert.are.same(vim.trim(lines[3]), vim.fn.getline('.'))

    assert.are.same({
      'import os',
      '',
      'print(os.uname())',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    assert.are.same({
      '* This is my source block',
      '  #+BEGIN_SRC python',
      '  import os',
      '',
      '  print(os.uname())',
      '#+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should change lines based on extmark as source buffer lines change', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 0

    local lines = {
      '* This is my source block',
      '#+BEGIN_SRC python',
      'import os',
      '',
      'print(os.uname())',
      '#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'python', startpos = { 3, 1 } })
    assert.are.same(vim.trim(lines[3]), vim.fn.getline('.'))

    assert.are.same({
      'import os',
      '',
      'print(os.uname())',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    -- Edit the source buffer
    vim.cmd('wincmd p')
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    vim.fn.cursor(1, 1)
    vim.cmd('norm O')
    vim.cmd('norm O')

    -- Delete all content in the edit special buffer
    vim.cmd('wincmd p')
    vim.cmd('norm ggdG')
    assert.are_not.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    -- Ensure the source buffer content changed correctly
    --
    -- Two new lines that we added on top, then all the content from the edit special
    -- buffer was deleted so that should be applied correctly as well
    assert.are.same({
      '',
      '',
      '* This is my source block',
      '#+BEGIN_SRC python',
      '',
      '#+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should abort despite changes when using abort keymap', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 0

    local lines = {
      '* This is my source block',
      '#+BEGIN_SRC python',
      'import os',
      '',
      'print(os.uname())',
      '#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'python', startpos = { 3, 1 } })
    assert.are.same(vim.trim(lines[3]), vim.fn.getline('.'))

    assert.are.same({
      'import os',
      '',
      'print(os.uname())',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    -- Delete all content in the edit special buffer
    vim.cmd('norm ggdG')
    vim.cmd('silent! norm ,ok')
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    -- Aborted, lines won't change
    assert.are.same(lines, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should strip leading spaces from content based on indent of source block no extra indentation', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 0

    local lines = {
      '* This is my source block',
      '  #+BEGIN_SRC sql',
      '  SELECT *',
      '  FROM dual;',
      '  #+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'sql', startpos = { 3, 1 } })
    assert.are.same(vim.trim(lines[3]), vim.fn.getline('.'))

    -- No leading indent on the block content in the edit special buffer
    assert.are.same({
      'SELECT *',
      'FROM dual;',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    -- No extra indentation when Org buffer is updated
    assert.are.same({
      '* This is my source block',
      '  #+BEGIN_SRC sql',
      '  SELECT *',
      '  FROM dual;',
      '  #+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should strip leading tabs from content based on indent of source block no extra indentation', function()
    vim.opt.expandtab = false
    config.org_edit_src_content_indentation = 0

    local lines = {
      '* This is my source block',
      '\t#+BEGIN_SRC sql',
      '\tSELECT *',
      '\tFROM dual;',
      '\t#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'sql', startpos = { 3, 1 } })
    assert.are.same(vim.trim(lines[3]), vim.fn.getline('.'))

    -- No leading indent on the block content in the edit special buffer
    assert.are.same({
      'SELECT *',
      'FROM dual;',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    -- No extra indentation when Org buffer is updated
    assert.are.same({
      '* This is my source block',
      '\t#+BEGIN_SRC sql',
      '\tSELECT *',
      '\tFROM dual;',
      '\t#+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should add leading spaces to source block content based on configured indent', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 2

    local lines = {
      '* This is my source block',
      '  #+BEGIN_SRC sql',
      '  SELECT *',
      '  FROM dual;',
      '  #+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'sql', startpos = { 3, 1 } })
    assert.are.same(vim.trim(lines[3]), vim.fn.getline('.'))

    -- No leading indent on the block content in the edit special buffer
    assert.are.same({
      'SELECT *',
      'FROM dual;',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    -- Extra spaces are added based on the configured indent value (in this case 2 extra tabs
    -- beyond the indent of the block itself)
    assert.are.same({
      '* This is my source block',
      '  #+BEGIN_SRC sql',
      '    SELECT *',
      '    FROM dual;',
      '  #+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should add leading tabs to source block content based on configured indent', function()
    vim.opt.expandtab = false
    config.org_edit_src_content_indentation = 2

    local lines = {
      '* This is my source block',
      '\t#+BEGIN_SRC sql',
      '\tSELECT *',
      '\tFROM dual;',
      '\t#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'sql', startpos = { 3, 1 } })
    assert.are.same(vim.trim(lines[3]), vim.fn.getline('.'))

    -- No leading indent on the block content in the edit special buffer
    assert.are.same({
      'SELECT *',
      'FROM dual;',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    -- Extra tabs are added based on the configured indent value (in this case 2 extra tabs
    -- beyond the indent of the block itself)
    assert.are.same({
      '* This is my source block',
      '\t#+BEGIN_SRC sql',
      '\t\t\tSELECT *',
      '\t\t\tFROM dual;',
      '\t#+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should determine indent character based on expandtab value', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 2

    local lines = {
      '* This is my source block',
      '\t#+BEGIN_SRC sql',
      '\tSELECT *',
      '\tFROM dual;',
      '\t#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'sql', startpos = { 3, 1 } })
    assert.are.same(vim.trim(lines[3]), vim.fn.getline('.'))

    -- No leading indent on the block content in the edit special buffer
    assert.are.same({
      'SELECT *',
      'FROM dual;',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    -- Inside of the source block we get spaces instead of tabs, even though the rest
    -- of the block is indented at a base level with tabs
    assert.are.same({
      '* This is my source block',
      '\t#+BEGIN_SRC sql',
      '\t  SELECT *',
      '\t  FROM dual;',
      '\t#+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should properly edit empty blocks', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 0

    local lines = {
      '* This is my source block',
      '#+BEGIN_SRC sql',
      '#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'sql', startpos = { 3, 1 } })
    assert.are.same('', vim.fn.getline('.'))

    -- No content to edit
    assert.are.same({ '' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    -- Default is to set content to an empty line
    assert.are.same({
      '* This is my source block',
      '#+BEGIN_SRC sql',
      '',
      '#+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should update Org buffer contents when write action occurs in the edit special buffer', function()
    vim.opt.expandtab = true
    config.org_edit_src_content_indentation = 0

    local lines = {
      '* This is my source block',
      '#+BEGIN_SRC sql',
      'SELECT *',
      'FROM dual;',
      '#+END_SRC',
      '* This is unrelated text',
    }

    setup_test({ lines = lines, ft = 'sql', startpos = { 3, 1 } })
    assert.are.same('SELECT *', vim.fn.getline('.'))

    assert.are.same({
      'SELECT *',
      'FROM dual;',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd([[norm gg]])
    assert.are.same('SELECT *', vim.fn.getline('.'))
    vim.cmd([[norm dd]])

    -- Lines updated in the original Org buffer after the write action completes
    vim.cmd([[norm ,ow]])
    assert.are.same({
      '* This is my source block',
      '#+BEGIN_SRC sql',
      'FROM dual;',
      '#+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(start_org_bufnr, 0, -1, false))

    vim.cmd([[silent! write | quit]])
    assert.are.same(start_org_bufnr, vim.api.nvim_get_current_buf())

    assert.are.same({
      '* This is my source block',
      '#+BEGIN_SRC sql',
      'FROM dual;',
      '#+END_SRC',
      '* This is unrelated text',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
end)

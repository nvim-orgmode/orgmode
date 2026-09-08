local Buffers = require('orgmode.state.buffers')
local helpers = require('tests.plenary.helpers')

describe('Buffers', function()
  it('should return -1 for non-existent files', function()
    local result = Buffers.get_buffer_by_filename('/this/file/does/not/exist.org')
    assert.are.same(-1, result)
  end)

  it('should return buffer number for loaded files', function()
    local file = helpers.create_file({ '* Test headline' }, 'some_filename.org')
    local result = Buffers.get_buffer_by_filename(file.filename)
    assert.is.True(result > 0)
  end)

  it('should handle filenames with special regex characters', function()
    -- Test various special characters that would break unescaped regex
    local test_cases = {
      '[test].org',
      '(test).org',
      'test[1].org',
      'file.with.dots.org',
      'file+plus.org',
      'file*star.org',
      'file?question.org',
      'file$dollar.org',
      'file^caret.org',
    }

    for _, special_filename in ipairs(test_cases) do
      local file = helpers.create_file({ '* Test headline' }, special_filename)
      local result = Buffers.get_buffer_by_filename(file.filename)
      assert.is.True(result > 0, 'Failed for filename: ' .. special_filename)

      vim.cmd('bdelete')
    end
  end)

  it('should find a buffer opened after the file was looked up and missed', function()
    local fname = vim.fn.tempname() .. '.org'

    assert.are.same(-1, Buffers.get_buffer_by_filename(fname))

    vim.fn.writefile({ '* Test headline' }, fname)
    vim.cmd.edit(fname)

    assert.is.True(Buffers.get_buffer_by_filename(fname) > 0)
    vim.cmd('bwipeout')
  end)

  it('should find a non-org filename once its filetype is set to org', function()
    local fname = vim.fn.tempname() .. '.txt'
    vim.fn.writefile({ '* Test headline' }, fname)

    assert.are.same(-1, Buffers.get_buffer_by_filename(fname))

    vim.cmd.edit(fname)
    vim.bo.filetype = 'org'

    assert.is.True(Buffers.get_buffer_by_filename(fname) > 0)
    vim.cmd('bwipeout')
  end)

  it('should not map the old name to a renamed buffer', function()
    local file = helpers.create_file({ '* Test headline' })
    local old_name = file.filename
    local new_name = vim.fn.tempname() .. '.org'

    local bufnr = Buffers.get_buffer_by_filename(old_name)
    assert.is.True(bufnr > 0)

    vim.cmd('file ' .. vim.fn.fnameescape(new_name))
    vim.cmd('write')

    -- `:file` leaves an unlisted buffer holding the old name, so the old name
    -- may still resolve to something. It must not resolve to this buffer.
    assert.are_not.same(bufnr, Buffers.get_buffer_by_filename(old_name))
    assert.are.same(bufnr, Buffers.get_buffer_by_filename(new_name))
    vim.cmd('bwipeout')
  end)

  it('should return -1 for unloaded buffers', function()
    local file = helpers.create_file({ '* Test headline' })
    local filename = file.filename

    -- First verify it works when loaded
    local result_loaded = Buffers.get_buffer_by_filename(filename)
    assert.is.True(result_loaded > 0)

    -- Wipe the buffer (this actually unloads it from memory)
    vim.cmd('bwipeout')

    -- Should return -1 for wiped buffer
    local result_unloaded = Buffers.get_buffer_by_filename(filename)
    assert.are.same(-1, result_unloaded)
  end)
end)

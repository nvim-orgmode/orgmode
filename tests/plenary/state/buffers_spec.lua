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

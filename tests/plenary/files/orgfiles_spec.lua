local OrgFiles = require('orgmode.files')

describe('OrgFiles', function()
  local temp_dir
  local test_files = {}

  before_each(function()
    temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, 'p')
    test_files = {}
  end)

  after_each(function()
    for _, file in ipairs(test_files) do
      vim.fn.delete(file)
    end
    vim.fn.delete(temp_dir, 'rf')
  end)

  ---@param name string
  ---@param content string[]
  ---@return string filepath
  local function create_test_file(name, content)
    local filepath = temp_dir .. '/' .. name
    vim.fn.writefile(content, filepath)
    table.insert(test_files, filepath)
    return filepath
  end

  describe('scan', function()
    it('should return metadata for all org files', function()
      local file1 = create_test_file('test1.org', { '* Headline 1' })
      local file2 = create_test_file('test2.org', { '* Headline 2', '** Sub headline' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })
      local metadata = files:scan()

      assert.are.equal(2, #metadata)

      -- Verify structure of returned metadata
      for _, entry in ipairs(metadata) do
        assert.is_not_nil(entry.filename)
        assert.is_not_nil(entry.mtime_sec)
        assert.is_not_nil(entry.mtime_nsec)
        assert.is_not_nil(entry.size)
        assert.is_true(entry.size > 0)
      end

      -- Verify filenames are correct
      local filenames = vim.tbl_map(function(m)
        return m.filename
      end, metadata)
      table.sort(filenames)
      assert.is_true(vim.tbl_contains(filenames, file1))
      assert.is_true(vim.tbl_contains(filenames, file2))
    end)

    it('should return empty table for empty paths', function()
      local empty_dir = vim.fn.tempname()
      vim.fn.mkdir(empty_dir, 'p')

      local files = OrgFiles:new({ paths = { empty_dir .. '/*.org' } })
      local metadata = files:scan()

      assert.are.same({}, metadata)
      vim.fn.delete(empty_dir, 'rf')
    end)

    it('should filter out non-org files', function()
      create_test_file('test.org', { '* Headline' })
      create_test_file('readme.txt', { 'Not an org file' })
      create_test_file('notes.md', { '# Markdown' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*' } })
      local metadata = files:scan()

      assert.are.equal(1, #metadata)
      assert.is_true(metadata[1].filename:match('%.org$') ~= nil)
    end)

    it('should return correct mtime matching file state', function()
      local filepath = create_test_file('timed.org', { '* Test' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })
      local metadata = files:scan()

      assert.are.equal(1, #metadata)

      local stat = vim.uv.fs_stat(filepath)
      assert.are.equal(stat.mtime.sec, metadata[1].mtime_sec)
      assert.are.equal(stat.mtime.nsec, metadata[1].mtime_nsec)
      assert.are.equal(stat.size, metadata[1].size)
    end)

    it('should handle missing/deleted files gracefully', function()
      local file1 = create_test_file('exists.org', { '* Exists' })
      local file2 = create_test_file('will_delete.org', { '* Will be deleted' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })

      -- Delete file before scanning
      vim.fn.delete(file2)

      local metadata = files:scan()

      assert.are.equal(1, #metadata)
      assert.are.equal(file1, metadata[1].filename)
    end)

    it('should be fast (benchmark with multiple files)', function()
      -- Create 20 files for benchmark
      for i = 1, 20 do
        create_test_file(string.format('file%02d.org', i), { '* Headline ' .. i })
      end

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })

      local start = vim.uv.hrtime()
      local metadata = files:scan()
      local elapsed_ms = (vim.uv.hrtime() - start) / 1e6

      assert.are.equal(20, #metadata)
      -- Should complete in under 100ms for 20 files (very conservative)
      assert.is_true(elapsed_ms < 100, 'scan() took ' .. elapsed_ms .. 'ms, expected < 100ms')
    end)
  end)
end)

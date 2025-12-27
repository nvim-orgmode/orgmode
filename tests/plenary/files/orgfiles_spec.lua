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

  describe('_sort_metadata', function()
    it('should sort by mtime descending by default', function()
      local files = OrgFiles:new({ paths = {} })
      local metadata = {
        { filename = 'old.org', mtime_sec = 100, mtime_nsec = 0 },
        { filename = 'new.org', mtime_sec = 200, mtime_nsec = 0 },
      }

      files:_sort_metadata(metadata, {})

      assert.are.equal('new.org', metadata[1].filename)
      assert.are.equal('old.org', metadata[2].filename)
    end)

    it('should sort by mtime ascending when specified', function()
      local files = OrgFiles:new({ paths = {} })
      local metadata = {
        { filename = 'new.org', mtime_sec = 200, mtime_nsec = 0 },
        { filename = 'old.org', mtime_sec = 100, mtime_nsec = 0 },
      }

      files:_sort_metadata(metadata, { order_by = 'mtime', direction = 'asc' })

      assert.are.equal('old.org', metadata[1].filename)
      assert.are.equal('new.org', metadata[2].filename)
    end)

    it('should use mtime_nsec as tiebreaker', function()
      local files = OrgFiles:new({ paths = {} })
      local metadata = {
        { filename = 'first.org', mtime_sec = 100, mtime_nsec = 500 },
        { filename = 'second.org', mtime_sec = 100, mtime_nsec = 1000 },
      }

      files:_sort_metadata(metadata, { order_by = 'mtime', direction = 'desc' })

      assert.are.equal('second.org', metadata[1].filename)
      assert.are.equal('first.org', metadata[2].filename)
    end)

    it('should sort by name ascending by default', function()
      local files = OrgFiles:new({ paths = {} })
      local metadata = {
        { filename = 'zebra.org' },
        { filename = 'alpha.org' },
        { filename = 'middle.org' },
      }

      files:_sort_metadata(metadata, { order_by = 'name' })

      assert.are.equal('alpha.org', metadata[1].filename)
      assert.are.equal('middle.org', metadata[2].filename)
      assert.are.equal('zebra.org', metadata[3].filename)
    end)

    it('should sort by name descending when specified', function()
      local files = OrgFiles:new({ paths = {} })
      local metadata = {
        { filename = 'alpha.org' },
        { filename = 'zebra.org' },
      }

      files:_sort_metadata(metadata, { order_by = 'name', direction = 'desc' })

      assert.are.equal('zebra.org', metadata[1].filename)
      assert.are.equal('alpha.org', metadata[2].filename)
    end)

    it('should use custom sort function', function()
      local files = OrgFiles:new({ paths = {} })
      local metadata = {
        { filename = 'small.org', size = 10 },
        { filename = 'large.org', size = 100 },
      }

      files:_sort_metadata(metadata, {
        order_by = function(a, b)
          return a.size > b.size
        end,
      })

      assert.are.equal('large.org', metadata[1].filename)
      assert.are.equal('small.org', metadata[2].filename)
    end)
  end)

  describe('load_progressive', function()
    it('should load all files and call on_complete callback', function()
      create_test_file('test1.org', { '* Headline 1' })
      create_test_file('test2.org', { '* Headline 2' })
      create_test_file('test3.org', { '* Headline 3' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })
      local completed = false
      local loaded_files = {}

      files
        :load_progressive({
          current_buffer_first = false,
          on_complete = function(all_files)
            completed = true
            loaded_files = all_files
          end,
        })
        :wait()

      assert.is_true(completed)
      assert.are.equal(3, #loaded_files)
      assert.are.equal(3, #files:all())
    end)

    it('should call on_file_loaded callback for each file', function()
      create_test_file('test1.org', { '* Headline 1' })
      create_test_file('test2.org', { '* Headline 2' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })
      local callback_calls = {}

      files
        :load_progressive({
          current_buffer_first = false,
          on_file_loaded = function(file, index, total)
            table.insert(callback_calls, {
              filename = file.filename,
              index = index,
              total = total,
            })
          end,
        })
        :wait()

      assert.are.equal(2, #callback_calls)
      for _, call in ipairs(callback_calls) do
        assert.are.equal(2, call.total)
        assert.is_true(call.index >= 1 and call.index <= 2)
      end
    end)

    it('should apply filter before loading', function()
      create_test_file('include.org', { '* Include me' })
      create_test_file('exclude.org', { '* Exclude me' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })
      local loaded_files = {}

      files
        :load_progressive({
          current_buffer_first = false,
          filter = function(metadata)
            return metadata.filename:match('include') ~= nil
          end,
          on_complete = function(all_files)
            loaded_files = all_files
          end,
        })
        :wait()

      assert.are.equal(1, #loaded_files)
      assert.is_true(loaded_files[1].filename:match('include') ~= nil)
    end)

    it('should track progress state correctly', function()
      create_test_file('test1.org', { '* Headline 1' })
      create_test_file('test2.org', { '* Headline 2' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })

      -- Initially no progress state
      assert.is_nil(files:get_load_progress())

      files
        :load_progressive({
          current_buffer_first = false,
        })
        :wait()

      local progress = files:get_load_progress()
      assert.is_not_nil(progress)
      assert.are.equal(2, progress.loaded)
      assert.are.equal(2, progress.total)
      assert.is_false(progress.loading)
    end)

    it('should handle empty file list gracefully', function()
      local empty_dir = vim.fn.tempname()
      vim.fn.mkdir(empty_dir, 'p')

      local files = OrgFiles:new({ paths = { empty_dir .. '/*.org' } })
      local completed = false

      files
        :load_progressive({
          on_complete = function()
            completed = true
          end,
        })
        :wait()

      assert.is_true(completed)
      local progress = files:get_load_progress()
      assert.are.equal(0, progress.total)
      assert.are.equal(0, progress.loaded)
      assert.is_false(progress.loading)

      vim.fn.delete(empty_dir, 'rf')
    end)
  end)

  describe('request_load', function()
    it('should be idempotent - multiple calls load files only once', function()
      create_test_file('test1.org', { '* Headline 1' })
      create_test_file('test2.org', { '* Headline 2' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })
      local load_count = 0

      -- Call request_load twice before either completes
      local promise1 = files:request_load({
        on_complete = function()
          load_count = load_count + 1
        end,
      })
      local promise2 = files:request_load({
        on_complete = function()
          load_count = load_count + 1
        end,
      })

      -- Wait for both
      promise1:wait()
      promise2:wait()

      -- Files should be loaded exactly once, both callbacks called
      assert.are.equal('loaded', files.load_state)
      assert.are.equal(2, #files:all())
      assert.are.equal(2, load_count) -- Both callbacks called
    end)

    it('should chain onto existing promise when already loading', function()
      create_test_file('test1.org', { '* Headline 1' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })
      local callback_order = {}

      -- Start first load
      local promise1 = files:request_load({
        on_complete = function()
          table.insert(callback_order, 'first')
        end,
      })

      -- Chain second load while first is in progress
      local promise2 = files:request_load({
        on_complete = function()
          table.insert(callback_order, 'second')
        end,
      })

      -- Wait for both
      promise1:wait()
      promise2:wait()

      -- Both callbacks should have been called
      assert.are.equal(2, #callback_order)
      assert.is_true(vim.tbl_contains(callback_order, 'first'))
      assert.is_true(vim.tbl_contains(callback_order, 'second'))
    end)

    it('should return resolved promise when already loaded', function()
      create_test_file('test1.org', { '* Headline 1' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })

      -- First load
      files:request_load():wait()
      assert.are.equal('loaded', files.load_state)

      -- Second call should return immediately
      local callback_called = false
      local promise = files:request_load({
        on_complete = function()
          callback_called = true
        end,
      })

      -- Should resolve immediately (already loaded)
      promise:wait()
      assert.is_true(callback_called)
    end)
  end)

  describe('request_load_sync', function()
    it('should block until files are loaded', function()
      create_test_file('test1.org', { '* Headline 1' })
      create_test_file('test2.org', { '* Headline 2' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })

      -- Should block and return loaded files
      local result = files:request_load_sync(5000)

      assert.are.equal('loaded', files.load_state)
      assert.are.equal(files, result)
      assert.are.equal(2, #files:all())
    end)

    it('should work when already loaded', function()
      create_test_file('test1.org', { '* Headline 1' })

      local files = OrgFiles:new({ paths = { temp_dir .. '/*.org' } })

      -- First load
      files:request_load_sync(5000)

      -- Second call should return immediately
      local start = vim.uv.hrtime()
      local result = files:request_load_sync(5000)
      local elapsed_ms = (vim.uv.hrtime() - start) / 1e6

      assert.are.equal(files, result)
      -- Should be nearly instant (< 10ms) since already loaded
      assert.is_true(elapsed_ms < 10, 'request_load_sync took ' .. elapsed_ms .. 'ms when already loaded')
    end)
  end)
end)

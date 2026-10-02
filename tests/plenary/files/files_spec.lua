local OrgFiles = require('orgmode.files')

describe('OrgFiles', function()
  describe('path discovery', function()
    local discover_calls = 0
    local dir
    ---@type OrgFiles
    local files

    before_each(function()
      discover_calls = 0
      dir = vim.fn.tempname()
      vim.fn.mkdir(dir, 'p')
      vim.fn.writefile({ '* One' }, dir .. '/one.org')
      files = OrgFiles:new({ paths = { dir .. '/**/*' } })
      local discover_files = files._discover_files
      files._discover_files = function(...)
        discover_calls = discover_calls + 1
        return discover_files(...)
      end
    end)

    after_each(function()
      vim.fn.delete(dir, 'rf')
    end)

    it('should discover paths once per load and reuse the result', function()
      files:load():wait()
      assert.are.same(1, discover_calls)

      files:all()
      files:all()
      assert.are.same(1, discover_calls)

      files:load(true):wait()
      assert.are.same(2, discover_calls)
    end)
  end)

  describe('finding files', function()
    local dir

    ---@param paths string[]
    ---@return string[] Found files, relative to the test directory
    local function find(paths)
      local found = OrgFiles:new({ paths = paths }):_discover_files():wait()
      local resolved_dir = vim.fn.resolve(dir)
      return vim.tbl_map(function(file)
        return file:sub(#resolved_dir + 2)
      end, found)
    end

    before_each(function()
      dir = vim.fn.tempname()
      for _, path in ipairs({ 'a', 'B', 'sub/deep', 'sub/dir.org', '.hidden_dir', 'outside' }) do
        vim.fn.mkdir(dir .. '/' .. path, 'p')
      end
      for _, file in ipairs({
        'top.org',
        'a.org',
        'Z.org',
        '.hidden.org',
        'notes.org_archive',
        'readme.md',
        'a/low.org',
        'B/up.org',
        'sub/deep/y.org',
        'sub/dir.org/inner.org',
        '.hidden_dir/h.org',
        'outside/linked.org',
      }) do
        vim.fn.writefile({ '* Headline' }, dir .. '/' .. file)
      end
      vim.uv.fs_symlink(dir .. '/outside', dir .. '/sub/linkdir')
    end)

    local wildignore = vim.o.wildignore
    after_each(function()
      vim.o.wildignore = wildignore
      vim.fn.delete(dir, 'rf')
    end)

    ---Files found by `vim.fn.glob()`, which was used before, relative to the test directory
    ---@param paths string[]
    ---@return string[]
    local function glob(paths)
      local resolved_dir = vim.fn.resolve(dir)
      local found = {}
      for _, path in ipairs(paths) do
        for _, file in ipairs(vim.fn.glob(path, false, true)) do
          local stat = vim.uv.fs_stat(file)
          if file:match('%.org$') or file:match('%.org_archive$') then
            if stat and stat.type == 'file' then
              table.insert(found, vim.fn.resolve(file):sub(#resolved_dir + 2))
            end
          end
        end
      end
      return found
    end

    it('should find the same files in the same order as glob', function()
      for _, pattern in ipairs({
        '/**/*',
        '/**',
        '/*',
        '/*/*.org',
        '/**/*.org',
        '/{a,B}/*',
        '/?.org',
        '/top.org',
        '/missing.org',
        '/readme.md',
        '/.*',
        '/.hidden_dir/*',
        '/**/',
      }) do
        local paths = { dir .. pattern }
        assert.are.same(glob(paths), find(paths), pattern)
      end
    end)

    it('should apply wildignore like glob', function()
      for _, ignored in ipairs({ '*/deep/*', '*.org_archive', '*/sub/*,a.org', 'top.org' }) do
        vim.o.wildignore = ignored
        for _, pattern in ipairs({ '/**/*', '/*', '/top.org' }) do
          local paths = { dir .. pattern }
          assert.are.same(glob(paths), find(paths), ignored .. ' ' .. pattern)
        end
      end
    end)

    it('should skip hidden files and follow symlinks', function()
      local found = find({ dir .. '/**/*' })
      assert.is_false(vim.tbl_contains(found, '.hidden.org'))
      assert.is_false(vim.tbl_contains(found, '.hidden_dir/h.org'))
      -- Once from the directory itself and once through the symlink to it
      assert.are.same(2, #vim.tbl_filter(function(file)
        return file == 'outside/linked.org'
      end, found))
    end)

    it('should keep the order of multiple paths', function()
      local paths = { dir .. '/top.org', dir .. '/*/*.org', dir .. '/top.org' }
      assert.are.same(glob(paths), find(paths))
    end)
  end)
end)

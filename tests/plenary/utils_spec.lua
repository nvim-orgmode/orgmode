local utils = require('orgmode.utils')
local helpers = require('tests.plenary.helpers')

describe('Util', function()
  describe('reduce', function()
    local nums = { 1, 2, 3 }

    it('works on sums', function()
      local sum = utils.reduce(nums, function(acc, num)
        return acc + num
      end, 0)
      assert.are.same(6, sum)
    end)

    it('works on products', function()
      local multiplied = utils.reduce(nums, function(acc, num)
        table.insert(acc, num * 2)
        return acc
      end, {})
      assert.are.same({ 2, 4, 6 }, multiplied)
    end)
  end)

  describe('current_file_path', function()
    it('returns the buffer name', function()
      local file = helpers.create_file({})
      assert.are.Not.same('', file.filename)
      assert.are.same(file.filename, utils.current_file_path())
    end)
    it('always returns the full path', function()
      local file = helpers.create_file({})
      local dirname = vim.fs.dirname(file.filename)
      helpers.with_cwd(dirname, function()
        local relpath = vim.fn.bufname()
        local abspath = utils.current_file_path()
        assert(vim.endswith(abspath, relpath))
        assert.are.Not.same(abspath, relpath)
      end)
    end)
  end)

  describe('readfile', function()
    ---@type OrgFile
    local file
    before_each(function()
      if not file then
        file = helpers.create_file({
          'First line',
          '',
          '* Headline',
          'Contents',
        })
      end
    end)

    it('returns lines', function()
      local contents = utils.readfile(file.filename):wait()
      assert.are.same(contents, {
        'First line',
        '',
        '* Headline',
        'Contents',
      })
    end)

    it('returns raw contents', function()
      local contents = utils.readfile(file.filename, { raw = true }):wait()
      assert.are.equal(contents, 'First line\n\n* Headline\nContents\n')
    end)

    it('schedules its results for later', function()
      utils
        .readfile(file.filename, { schedule = true })
        :next(function(contents)
          -- Without `schedule = true`, this line would run inside `fast-api`
          -- and thus fail.
          vim.fn.setreg('', contents)
        end)
        :wait()
      local contents = vim.fn.getreg('')
      assert.are.equal(contents, 'First line\n\n* Headline\nContents\n')
    end)
  end)

  describe('writefile', function()
    ---@type string
    local filename
    before_each(function()
      if not filename then
        filename = vim.fn.tempname()
      end
    end)

    local contents = {
      'First line',
      '',
      '* Headline',
      'Contents',
    }

    it('writes bare strings', function()
      local bytes = utils.writefile(filename, table.concat(contents, '\n')):wait()
      assert.are.equal(bytes, 31)
      local reread = vim.fn.readfile(filename)
      assert.are.same(reread, contents)
    end)

    it('writes lists of strings by concatenation', function()
      local bytes = utils.writefile(filename, contents):wait()
      assert.are.equal(bytes, 28)
      local reread = vim.fn.readfile(filename)
      assert.are.same(reread, { 'First line* HeadlineContents' })
    end)

    it('does not schedule its results', function()
      local promise = utils.writefile(filename, contents):next(function(bytes)
        return vim.fn.setreg('', bytes)
      end)
      ---@type boolean, string?
      local ok, err = pcall(promise.wait, promise)
      assert.is.False(ok)
      assert(err)
      local expected = 'E5560: Vimscript function'
      local msg = err:sub(1, #expected)
      assert.are.equal(expected, msg)
    end)

    it('allows no-clobber writes', function()
      local promise = utils.writefile(filename, contents, { excl = true })
      ---@type boolean, string?
      local ok, err = pcall(promise.wait, promise)
      assert.is.False(ok)
      assert(err)
      local expected = 'EEXIST: file already exists: ' .. filename
      assert.are.equal(expected, err)
    end)
  end)
end)

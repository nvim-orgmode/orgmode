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
end)

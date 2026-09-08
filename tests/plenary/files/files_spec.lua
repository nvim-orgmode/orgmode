local OrgFiles = require('orgmode.files')

describe('OrgFiles', function()
  describe('path discovery', function()
    local glob = vim.fn.glob
    local glob_calls = 0
    local dir
    ---@type OrgFiles
    local files

    before_each(function()
      glob_calls = 0
      vim.fn.glob = function(...)
        glob_calls = glob_calls + 1
        return glob(...)
      end
      dir = vim.fn.tempname()
      vim.fn.mkdir(dir, 'p')
      vim.fn.writefile({ '* One' }, dir .. '/one.org')
      files = OrgFiles:new({ paths = { dir .. '/**/*' } })
    end)

    after_each(function()
      vim.fn.glob = glob
      vim.fn.delete(dir, 'rf')
    end)

    it('should discover paths once per load and reuse the result', function()
      files:load():wait()
      assert.are.same(1, glob_calls)

      files:all()
      files:all()
      assert.are.same(1, glob_calls)

      files:load(true):wait()
      assert.are.same(2, glob_calls)
    end)
  end)
end)

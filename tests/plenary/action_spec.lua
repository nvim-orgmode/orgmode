local orgmode = require('orgmode')
local Promise = require('orgmode.utils.promise')

describe('Org.action', function()
  it('should await promise-returning methods without manual coroutine management', function()
    local mappings = orgmode.instance().org_mappings
    local original = mappings.awaited_test
    local called = false

    mappings.awaited_test = function()
      return Promise.new(function(resolve)
        vim.defer_fn(function()
          called = true
          resolve('done')
        end, 10)
      end)
    end

    local ok, result = pcall(function()
      return orgmode.action('org_mappings.awaited_test'):wait(100)
    end)

    mappings.awaited_test = original

    assert.is_true(ok)
    assert.is_true(called)
    assert.are.same('done', result)
  end)
end)

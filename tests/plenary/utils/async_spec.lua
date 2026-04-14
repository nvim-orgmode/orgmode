local Async = require('orgmode.utils.async')

describe('Async', function()
  it('awaits callback-based work inside a coroutine', function()
    local result = Async.run(function()
      return Async.await(1, function(callback)
        callback('ok')
      end)
    end):wait()

    assert.are.same('ok', result)
  end)

  it('awaits nested async tasks', function()
    local result = Async.run(function()
      local task = Async.run(function()
        return 'nested'
      end)

      return task:await()
    end):wait()

    assert.are.same('nested', result)
  end)
end)

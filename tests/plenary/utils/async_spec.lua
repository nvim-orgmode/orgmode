local Async = require('orgmode.utils.async')
local Promise = require('orgmode.utils.promise')

describe('Async', function()
  it('awaits org promises inside a coroutine', function()
    local result = Async.run(function()
      return Async.await_promise(Promise.resolve('ok'))
    end):wait()

    assert.are.same('ok', result)
  end)

  it('awaits nested async tasks', function()
    local result = Async.run(function()
      local task = Async.run(function()
        return Async.await_promise(Promise.resolve('nested'))
      end)

      return Async.awaitable(task)
    end):wait()

    assert.are.same('nested', result)
  end)
end)

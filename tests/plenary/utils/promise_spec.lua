local Promise = require('orgmode.utils.promise')

describe('Promise', function()
  it('should throw an error when wait exceeds its timeout', function()
    -- Create a promise that will never resolve or reject
    local promise = Promise.new(function() end)

    -- We expect an error to occur here when the timeout is exceeded
    assert.is.error(function()
      -- Provide a smaller timeout so our test doesn't wait 5 seconds
      promise:wait(50)
    end)
  end)

  it('should await a fulfilled promise from a coroutine', function()
    local result = {}
    local promise = Promise.new(function(resolve)
      vim.defer_fn(function()
        resolve('first', 'second')
      end, 10)
    end)

    local thread = coroutine.create(function()
      result = { promise:await() }
    end)

    assert.is_true(coroutine.resume(thread))
    vim.wait(100, function()
      return #result > 0
    end)

    assert.are.same({ 'first', 'second' }, result)
  end)

  it('should throw when await is called from a non-yieldable context', function()
    local ok
    local err

    vim.schedule(function()
      ok, err = pcall(function()
        Promise.resolve('value'):await()
      end)
    end)

    vim.wait(100, function()
      return ok ~= nil
    end)

    assert.is_false(ok)
    assert.matches('yieldable async context', err)
  end)

  it('should propagate awaited rejections back into the coroutine', function()
    local ok
    local err
    local promise = Promise.new(function(_, reject)
      vim.defer_fn(function()
        reject('boom')
      end, 10)
    end)

    local thread = coroutine.create(function()
      ok, err = pcall(function()
        promise:await()
      end)
    end)

    assert.is_true(coroutine.resume(thread))
    vim.wait(100, function()
      return ok ~= nil
    end)

    assert.is_false(ok)
    assert.are.same('boom', err)
  end)

  it('should await already settled promises without yielding', function()
    local result = {}
    local thread = coroutine.create(function()
      result = { Promise.resolve('ready', 'now'):await() }
    end)

    assert.is_true(coroutine.resume(thread))
    assert.are.same({ 'ready', 'now' }, result)
  end)

  it('should run await flows without manual coroutine management', function()
    local result = Promise.async(function()
      return Promise.new(function(resolve)
        vim.defer_fn(function()
          resolve('auto')
        end, 10)
      end):await()
    end):wait(100)

    assert.are.same('auto', result)
  end)
end)

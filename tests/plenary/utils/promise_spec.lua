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
end)

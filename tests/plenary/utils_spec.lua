local utils = require('orgmode.utils')

describe('Utils', function()
  it('should properly reduce', function()
    local nums = { 1, 2, 3 }
    local sum = utils.reduce(nums, function(acc, num)
      return acc + num
    end, 0)
    assert.are.same(6, sum)

    local multiplied = utils.reduce(nums, function(acc, num)
      table.insert(acc, num * 2)
      return acc
    end, {})
    assert.are.same({2, 4, 6}, multiplied)
  end)
end)

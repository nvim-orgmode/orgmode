local config = require('orgmode.config')
local PriorityState = require('orgmode.objects.priority_state')

describe('Priority state', function()
  local alpha_config = function()
    config:extend({
      org_priority_highest = 'A',
      org_priority_default = 'C',
      org_priority_lowest = 'D',
    })
  end

  local numeric_config = function()
    config:extend({
      org_priority_highest = 1,
      org_priority_default = 5,
      org_priority_lowest = 15,
    })
  end

  local create_priority = function(prio)
    return PriorityState:new(prio, config:get_priority_range(), true)
  end

  local create_priority_non_default = function(prio)
    return PriorityState:new(prio, config:get_priority_range(), false)
  end

  it('should increase single numeric priority', function()
    numeric_config()
    local priority = create_priority(10)
    assert.are.same('9', priority:increase())
  end)

  it('should decrease single numeric priority', function()
    numeric_config()
    local priority = create_priority(9)
    assert.are.same('10', priority:decrease())
  end)

  it('should increase single alpha priority', function()
    alpha_config()
    local priority = create_priority('D')
    assert.are.same('C', priority:increase())
    assert.are.same('B', priority:increase())
    assert.are.same('A', priority:increase())
  end)

  it('should decrease single alpha priority', function()
    alpha_config()
    local priority = create_priority('B')
    assert.are.same('C', priority:decrease())
  end)

  it('should change to lowest priority when numeric increased beyond highest', function()
    numeric_config()
    local priority = create_priority('1')
    assert.are.same('15', priority:increase())
  end)

  it('should change to highest priority when numeric decreased beyond lowest', function()
    numeric_config()
    local priority = create_priority('15')
    assert.are.same('1', priority:decrease())
  end)

  it('should change to lowest priority when alpha increased beyond highest', function()
    alpha_config()
    local priority = create_priority('A')
    assert.are.same('D', priority:increase())
  end)

  it('should change to highest priority when alpha decreased beyond lowest', function()
    alpha_config()
    local priority = create_priority('D')
    assert.are.same('A', priority:decrease())
  end)

  it('should convert numeric priorities to a string for comparison', function()
    numeric_config()
    local priority = create_priority(1)
    assert.are.same(priority.priority, '1')
  end)

  it('should return the string representation of the value to use for sorting for alpha strings', function()
    alpha_config()
    local priority = create_priority('A')
    assert.are.same(-65, priority:get_sort_value())
  end)

  it('should return the string representation of the value to use for sorting for numeric strings', function()
    numeric_config()
    local priority = create_priority(1)
    assert.are.same(-49, priority:get_sort_value())
  end)

  it('should return default priority value if empty when sorting', function()
    alpha_config()
    local priority = create_priority('')
    assert.are.same(-1 * string.byte(config.org_priority_default), priority:get_sort_value())
  end)

  it('should compare alpha priorities correctly', function()
    alpha_config()
    local higher = create_priority('A')
    local lower = create_priority('B')
    assert.is.True(higher:get_sort_value() > lower:get_sort_value())
  end)

  it('should compare numeric priorities correctly', function()
    numeric_config()
    local higher = create_priority(1)
    local lower = create_priority(2)
    assert.is.True(higher:get_sort_value() > lower:get_sort_value())
  end)

  it('should change to default priority if priority increased and currently empty', function()
    alpha_config()
    local priority = create_priority('')
    assert.are.same('C', priority:increase())
  end)

  it('should change to default priority if priority decreased and currently empty', function()
    alpha_config()
    local priority = create_priority('')
    assert.are.same('C', priority:decrease())
  end)

  it('should change to default + 1 priority if priority increased and currently empty', function()
    alpha_config()
    local priority = create_priority_non_default('')
    assert.are.same('B', priority:increase())
  end)

  it('should change to default - 1 priority if priority decreased and currently empty', function()
    alpha_config()
    local priority = create_priority_non_default('')
    assert.are.same('D', priority:decrease())
  end)
end)

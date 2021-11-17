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
      org_priority_highest = 10,
      org_priority_default = 5,
      org_priority_lowest = 1,
    })
  end

  it('should increase single numeric priority', function()
    numeric_config()
    local priority = PriorityState:new(3)
    assert.are.same('2', priority:increase())
  end)

  it('should decrease single numeric priority', function()
    numeric_config()
    local priority = PriorityState:new(3)
    assert.are.same('4', priority:decrease())
  end)

  it('should increase single alpha priority', function()
    alpha_config()
    local priority = PriorityState:new('C')
    assert.are.same('B', priority:increase())
  end)

  it('should decrease single alpha priority', function()
    alpha_config()
    local priority = PriorityState:new('B')
    assert.are.same('C', priority:decrease())
  end)

  it('should change to empty priority when numeric increased beyond highest', function()
    numeric_config()
    local priority = PriorityState:new('10')
    assert.are.same('', priority:increase())
  end)

  it('should change to empty priority when numeric decreased beyond lowest', function()
    numeric_config()
    local priority = PriorityState:new('1')
    assert.are.same('', priority:decrease())
  end)

  it('should change to empty priority when alpha increased beyond highest', function()
    alpha_config()
    local priority = PriorityState:new('A')
    assert.are.same('', priority:increase())
  end)

  it('should change to empty priority when alpha decreased beyond lowest', function()
    alpha_config()
    local priority = PriorityState:new('D')
    assert.are.same('', priority:decrease())
  end)

  it('should convert numeric priorities to a string for comparison', function()
    numeric_config()
    local priority = PriorityState:new(1)
    assert.are.same(priority.priority, '1')
  end)

  it('should return the string representation of the value to use for sorting for alpha strings', function()
    alpha_config()
    local priority = PriorityState:new('A')
    assert.are.same(-65, priority:get_sort_value())
  end)

  it('should return the string representation of the value to use for sorting for numeric strings', function()
    numeric_config()
    local priority = PriorityState:new(1)
    assert.are.same(-49, priority:get_sort_value())
  end)

  it('should return default priority value if empty when sorting', function()
    alpha_config()
    local priority = PriorityState:new('')
    assert.are.same(-1 * string.byte(config.org_priority_default), priority:get_sort_value())
  end)

  it('should compare alpha priorities correctly', function()
    alpha_config()
    local higher = PriorityState:new('A')
    local lower = PriorityState:new('B')
    assert.Is.True(higher:get_sort_value() > lower:get_sort_value())
  end)

  it('should compare numeric priorities correctly', function()
    numeric_config()
    local higher = PriorityState:new(1)
    local lower = PriorityState:new(2)
    assert.Is.True(higher:get_sort_value() > lower:get_sort_value())
  end)

  it('should change to highest priority if priority increased and currently empty', function()
    alpha_config()
    local priority = PriorityState:new('')
    assert.are.same('D', priority:increase())
  end)

  it('should change to lowest priority if priority decreased and currently empty', function()
    alpha_config()
    local priority = PriorityState:new('')
    assert.are.same('A', priority:decrease())
  end)
end)

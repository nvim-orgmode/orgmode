local config = require('orgmode.config')
local helpers = require('tests.plenary.helpers')

describe('Priority mappings', function()
  local alpha_config = function()
    config:extend({
      org_priority_highest = 'A',
      org_priority_default = 'C',
      org_priority_lowest = 'E',
    })
  end

  local numeric_config = function()
    config:extend({
      org_priority_highest = 1,
      org_priority_default = 5,
      org_priority_lowest = 15,
    })
  end

  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should increase the priority of the current headline', function()
    helpers.create_file({
      '* TODO [#B] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO [#B] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ciR')
    assert.are.same('* TODO [#A] Test orgmode', vim.fn.getline(1))
  end)

  it('should decrease the priority of the current headline', function()
    helpers.create_file({
      '* TODO [#B] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO [#B] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm cir')
    assert.are.same('* TODO [#C] Test orgmode', vim.fn.getline(1))
  end)

  it('should set the priority based on the input key', function()
    helpers.create_file({
      '* TODO [#B] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO [#B] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ,o,a\r')
    assert.are.same('* TODO [#A] Test orgmode', vim.fn.getline(1))
  end)

  it('should remove the priority if <Space> is pressed', function()
    helpers.create_file({
      '* TODO [#B] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO [#B] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ,o, \r')
    assert.are.same('* TODO Test orgmode', vim.fn.getline(1))
  end)

  it('should add a priority if the item does not already have one', function()
    helpers.create_file({
      '* TODO Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* TODO Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ,o,a\r')
    assert.are.same('* TODO [#A] Test orgmode', vim.fn.getline(1))
  end)

  it('should add a priority if the item has no todo keyword', function()
    helpers.create_file({
      '* Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ,o,a\r')
    assert.are.same('* [#A] Test orgmode', vim.fn.getline(1))
  end)

  it('should increase the default character priority, when it is explicitly defined', function()
    alpha_config()
    helpers.create_file({
      '* [#C] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* [#C] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ciR')
    assert.are.same('* [#B] Test orgmode', vim.fn.getline(1))
  end)

  it('should increase a numeric priority, which is not explicitly defined', function()
    numeric_config()
    helpers.create_file({
      '* [#5] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* [#5] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ciR')
    assert.are.same('* [#4] Test orgmode', vim.fn.getline(1))
  end)

  it('should increase a character priority, which is not explicitly defined', function()
    alpha_config()
    helpers.create_file({
      '* [#D] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* [#D] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ciR')
    assert.are.same('* [#C] Test orgmode', vim.fn.getline(1))
  end)

  it('should increase a numeric priority, which is not explicitly defined', function()
    numeric_config()
    helpers.create_file({
      '* [#10] Test orgmode',
    })
    vim.fn.cursor(1, 1)
    assert.are.same('* [#10] Test orgmode', vim.fn.getline(1))
    vim.cmd('norm ciR')
    assert.are.same('* [#9] Test orgmode', vim.fn.getline(1))
  end)
end)

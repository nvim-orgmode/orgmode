local helpers = require('tests.plenary.helpers')

describe('Priority mappings', function()
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
end)

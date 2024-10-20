local config = require('orgmode.config')
local helpers = require('tests.plenary.helpers')
local org = require('orgmode')

local feed = function(keys, mode)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, true, true), mode, true)
end

describe('with list item', function()
  describe('increase indentation', function()
    before_each(function()
      helpers.create_file({
        '* Some headline',
        '  - content 1',
        '    - content sub 1',
        '    - content sub 2',
        '      - content subsub 1',
        '      - content subsub 2',
        '  - content 2',
        '',
      })
    end)

    it('with subitems', function()
      vim.fn.cursor(2, 1)
      vim.cmd([[norm >s]])
      assert.are.same('* Some headline', vim.fn.getline(1))
      assert.are.same('    - content 1', vim.fn.getline(2))
      assert.are.same('      - content sub 1', vim.fn.getline(3))
      assert.are.same('      - content sub 2', vim.fn.getline(4))
      assert.are.same('        - content subsub 1', vim.fn.getline(5))
      assert.are.same('        - content subsub 2', vim.fn.getline(6))
      assert.are.same('  - content 2', vim.fn.getline(7))
    end)

    it('without subitems', function()
      vim.fn.cursor(2, 1)
      vim.cmd([[norm >>]])
      assert.are.same('    - content 1', vim.fn.getline(2))
      assert.are.same('    - content sub 1', vim.fn.getline(3))
      assert.are.same('    - content sub 2', vim.fn.getline(4))
      assert.are.same('      - content subsub 1', vim.fn.getline(5))
      assert.are.same('      - content subsub 2', vim.fn.getline(6))
      assert.are.same('  - content 2', vim.fn.getline(7))
    end)
  end)
  describe('decrease indentation', function()
    before_each(function()
      helpers.create_file({
        '* Some headline',
        '  - parent',
        '    - content 1',
        '      - content sub 1',
        '      - content sub 2',
        '        - content subsub 1',
        '        - content subsub 2',
        '    - content 2',
      })
    end)
    it('with subitems', function()
      vim.fn.cursor(3, 1)
      vim.cmd([[norm <s]])
      assert.are.same('  - parent', vim.fn.getline(2))
      assert.are.same('  - content 1', vim.fn.getline(3))
      assert.are.same('    - content sub 1', vim.fn.getline(4))
      assert.are.same('    - content sub 2', vim.fn.getline(5))
      assert.are.same('      - content subsub 1', vim.fn.getline(6))
      assert.are.same('      - content subsub 2', vim.fn.getline(7))
      assert.are.same('    - content 2', vim.fn.getline(8))
    end)
    it('without subitems', function()
      vim.fn.cursor(3, 1)
      vim.cmd([[norm <<]])
      assert.are.same('  - parent', vim.fn.getline(2))
      assert.are.same('  - content 1', vim.fn.getline(3))
      assert.are.same('      - content sub 1', vim.fn.getline(4))
      assert.are.same('      - content sub 2', vim.fn.getline(5))
      assert.are.same('        - content subsub 1', vim.fn.getline(6))
      assert.are.same('        - content subsub 2', vim.fn.getline(7))
      assert.are.same('    - content 2', vim.fn.getline(8))
    end)
  end)
end)

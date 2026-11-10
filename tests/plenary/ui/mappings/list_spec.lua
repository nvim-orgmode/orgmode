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
  describe('move', function()
    before_each(function()
      helpers.create_file({
        '* Some headline',
        '  - [ ] content 1',
        '    - content sub 1',
        '    - content sub 2',
        '  - [X] content 2',
        '',
        '  - content 3',
        '* Other headline',
      })
    end)

    it('up together with subitems (org_move_subtree_up)', function()
      vim.fn.cursor(5, 5)
      vim.cmd([[norm ,oK]])
      assert.are.same({
        '* Some headline',
        '  - [X] content 2',
        '  - [ ] content 1',
        '    - content sub 1',
        '    - content sub 2',
        '',
        '  - content 3',
        '* Other headline',
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      assert.are.same({ 2, 5 }, { vim.fn.line('.'), vim.fn.col('.') })
    end)

    it('down together with subitems (org_move_subtree_down)', function()
      vim.fn.cursor(2, 1)
      vim.cmd([[norm ,oJ]])
      assert.are.same({
        '* Some headline',
        '  - [X] content 2',
        '  - [ ] content 1',
        '    - content sub 1',
        '    - content sub 2',
        '',
        '  - content 3',
        '* Other headline',
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      assert.are.same(3, vim.fn.line('.'))
    end)

    it('keeps blank lines between items in place', function()
      vim.fn.cursor(7, 1)
      vim.cmd([[norm ,oK]])
      assert.are.same({
        '* Some headline',
        '  - [ ] content 1',
        '    - content sub 1',
        '    - content sub 2',
        '  - content 3',
        '',
        '  - [X] content 2',
        '* Other headline',
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      assert.are.same(5, vim.fn.line('.'))
    end)

    it('only within the same list', function()
      vim.fn.cursor(4, 1)
      vim.cmd([[norm ,oJ]])
      vim.fn.cursor(3, 1)
      vim.cmd([[norm ,oK]])
      assert.are.same({
        '* Some headline',
        '  - [ ] content 1',
        '    - content sub 1',
        '    - content sub 2',
        '  - [X] content 2',
        '',
        '  - content 3',
        '* Other headline',
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      assert.are.same(3, vim.fn.line('.'))
    end)

    it('keeps the numbers of an ordered list', function()
      helpers.create_file({
        '* Some headline',
        '  1. first',
        '  2. second',
        '     text of second',
        '  3. third',
      })
      vim.fn.cursor(2, 1)
      vim.cmd([[norm ,oJ]])
      assert.are.same({
        '* Some headline',
        '  1. second',
        '     text of second',
        '  2. first',
        '  3. third',
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      assert.are.same(4, vim.fn.line('.'))
    end)

    it('up when it is the last item in the file', function()
      helpers.create_file({
        '* Some headline',
        '  - first',
        '  - last',
      })
      vim.fn.cursor(3, 1)
      vim.cmd([[norm ,oK]])
      assert.are.same({
        '* Some headline',
        '  - last',
        '  - first',
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      vim.cmd([[norm ,oJ]])
      assert.are.same({
        '* Some headline',
        '  - first',
        '  - last',
      }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      assert.are.same(3, vim.fn.line('.'))
    end)

    it('moves the headline when the cursor is not on a bullet', function()
      vim.fn.cursor(1, 1)
      vim.cmd([[norm ,oJ]])
      assert.are.same({
        '* Other headline',
        '* Some headline',
        '  - [ ] content 1',
      }, vim.api.nvim_buf_get_lines(0, 0, 3, false))
    end)
  end)
end)

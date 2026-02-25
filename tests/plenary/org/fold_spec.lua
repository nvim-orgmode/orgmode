local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')

describe('folding', function()
  it('works', function()
    helpers.create_file({
      '* First',
      '** Second',
      '*** Third',
      '**** Fourth',
      '***** Fifth',
      'text',
    })
    vim.cmd.normal({ 'GzM', bang = true })
    local foldlevel = vim.fn.foldlevel(6)
    assert.are.same(5, foldlevel)
  end)

  describe('fold boundary preservation', function()
    local original_todo_keywords

    before_each(function()
      original_todo_keywords = config.org_todo_keywords
    end)

    after_each(function()
      config.org_todo_keywords = original_todo_keywords
      vim.cmd([[%bw!]])
    end)

    it('maintains fold boundaries when cycling TODO state within same group', function()
      -- Configure TODO keywords with same-group transitions
      config:extend({
        org_todo_keywords = { 'TODO', 'NEXT', '|', 'DONE' },
      })

      helpers.create_file({
        '* TODO Task headline',
        'Body line 1',
        'Body line 2',
        'Body line 3',
        '* Second headline',
      })

      -- Fold the first headline
      vim.cmd('1')
      vim.cmd('normal! zc')
      vim.cmd('redraw!')

      -- Verify fold covers lines 1-4 (headline + 3 body lines)
      local fold_start = vim.fn.foldclosed(1)
      local fold_end = vim.fn.foldclosedend(1)
      assert.are.equal(1, fold_start, 'Fold should start at line 1')
      assert.are.equal(4, fold_end, 'Fold should end at line 4 before TODO change')

      -- Change TODO to NEXT (same group, no CLOSED timestamp added)
      vim.fn.cursor(1, 1)
      vim.cmd([[norm cit]])
      -- Wait for vim.schedule() callbacks to complete
      vim.wait(100)
      vim.cmd('redraw!')

      -- Verify fold boundaries are preserved
      local new_fold_start = vim.fn.foldclosed(1)
      local new_fold_end = vim.fn.foldclosedend(1)
      assert.are.equal(1, new_fold_start, 'Fold should still start at line 1')
      assert.are.equal(4, new_fold_end, 'Fold should still end at line 4 after TODO→NEXT')

      -- Verify the TODO state actually changed
      assert.are.same('* NEXT Task headline', vim.fn.getline(1))
    end)
  end)
end)

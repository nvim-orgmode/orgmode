local helpers = require('tests.plenary.helpers')
local Input = require('orgmode.ui.input')
local Promise = require('orgmode.utils.promise')
local orgmode = require('orgmode')

local function with_mock_input(value, fn)
  local original = Input.open
  Input.open = function()
    return Promise.resolve(value)
  end
  fn()
  Input.open = original
end

describe('Insert drawer mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('inserts custom drawer at cursor (org_insert_drawer)', function()
    helpers.create_file({
      '* TODO heading',
      'content line',
    })

    vim.fn.cursor(2, 1)
    with_mock_input('NOTES', function()
      orgmode.action('org_mappings.insert_drawer')
      vim.wait(50, function()
        return false
      end)
    end)

    assert.are.same({
      '* TODO heading',
      'content line',
      '  :NOTES:',
      '  ',
      '  :END:',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('inserts PROPERTIES drawer under headline when count prefix is provided', function()
    helpers.create_file({
      '* TODO heading',
      'content line',
    })

    vim.fn.cursor(1, 1)
    vim.cmd([[let v:count = 1]])
    orgmode.action('org_mappings.insert_drawer')
    vim.wait(50, function()
      return false
    end)

    assert.are.same({
      '* TODO heading',
      '  :PROPERTIES:',
      '  ',
      '  :END:',
      'content line',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
end)

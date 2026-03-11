local helpers = require('tests.plenary.helpers')
local orgmode = require('orgmode')
local Promise = require('orgmode.utils.promise')

describe('Add Note', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('includes heading title in note prompt', function()
    helpers.create_file({
      '* TODO Example Title',
      'Some content',
    })

    -- Place cursor on the headline
    vim.fn.cursor(1, 1)

    local captured_title = nil

    helpers.with_var(orgmode.capture, 'build_note_capture', function(_, title)
      captured_title = title
      -- Return a stub with an open() that resolves immediately
      return {
        open = function()
          return Promise.resolve({ 'Test note content' })
        end,
      }
    end, function()
      orgmode.action('org_mappings.add_note')
    end)

    assert.are.same('Insert note for Example Title.', captured_title)
  end)
end)

local helpers = require('tests.plenary.helpers')
local Date = require('orgmode.objects.date')

describe('Archive', function()
  it('should refile headline to archive and create archive file', function()
    local file = helpers.create_agenda_file({
      '* foobar',
      '* baz',
      '** foo',
    })
    assert.are.same(vim.fn.glob(vim.fn.fnamemodify(file.filename, ':p:h') .. '/**/*.org_archive', false, 1, 1), {})

    local now = Date.now()
    vim.cmd([[exe "norm ,o$"]])
    -- Pause to finish the archiving
    vim.wait(50)
    assert.are.same({
      '* baz',
      '** foo',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    assert.are.same(vim.fn.glob(vim.fn.fnamemodify(file.filename, ':p:h') .. '/**/*.org_archive', false, 1, 1), {
      file.filename .. '_archive',
    })
    vim.cmd(('edit %s'):format(file.filename .. '_archive'))
    assert.are.same({
      '* foobar',
      '  :PROPERTIES:',
      '  :ARCHIVE_TIME: ' .. now:to_string(),
      '  :ARCHIVE_FILE: ' .. file.filename,
      -- no ARCHIVE_OLPATH because top-level headline
      '  :ARCHIVE_CATEGORY: ' .. file:get_category(),
      '  :ARCHIVE_TODO: ',
      '  :END:',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('should set properties on top-level headline when refiling subtree', function()
    local file = helpers.create_agenda_file({
      '* foobar',
      '** baz',
      '* foo',
    })

    local now = Date.now()
    vim.cmd([[exe "norm ,o$"]])
    -- Pause to finish the archiving
    vim.wait(50)
    assert.are.same({
      '* foo',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd(('edit %s'):format(file.filename .. '_archive'))
    assert.are.same({
      '* foobar',
      '  :PROPERTIES:',
      '  :ARCHIVE_TIME: ' .. now:to_string(),
      '  :ARCHIVE_FILE: ' .. file.filename,
      -- no ARCHIVE_OLPATH because top-level headline
      '  :ARCHIVE_CATEGORY: ' .. file:get_category(),
      '  :ARCHIVE_TODO: ',
      '  :END:',
      '** baz',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('sets outline path when archiving lower-level headline', function()
    local file = helpers.create_agenda_file({
      '* foo',
      '** TODO bar',
      '*** TODO baz',
      '    Body text baz',
    })

    vim.cmd([[exe "norm G,o$"]])
    -- Pause to finish the archiving
    vim.wait(50)
    assert.are.same({
      '* foo',
      '** TODO bar',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd(('edit %s'):format(file.filename .. '_archive'))
    assert.are.same({
      '* TODO baz', -- keep todo state in the title
      '  :PROPERTIES:',
      '  :ARCHIVE_TIME: ' .. Date.now():to_string(),
      '  :ARCHIVE_FILE: ' .. file.filename,
      '  :ARCHIVE_OLPATH: foo/bar', -- remove todo state in any headline in outline path
      '  :ARCHIVE_CATEGORY: ' .. file:get_category(),
      '  :ARCHIVE_TODO: TODO',
      '  :END:',
      '  Body text baz',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('sets the correct archive category on the archived headline', function()
    local file = helpers.create_agenda_file({
      '* foobar',
      '  :PROPERTIES:',
      '  :CATEGORY: custom_category',
      '  :END:',
      '* foo',
    })

    local now = Date.now()
    vim.cmd([[exe "norm ,o$"]])
    -- Pause to finish the archiving
    vim.wait(50)
    assert.are.same({
      '* foo',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))

    vim.cmd(('edit %s'):format(file.filename .. '_archive'))
    assert.are.same({
      '* foobar',
      '  :PROPERTIES:',
      '  :CATEGORY: custom_category',
      '  :ARCHIVE_TIME: ' .. now:to_string(),
      '  :ARCHIVE_FILE: ' .. file.filename,
      '  :ARCHIVE_CATEGORY: custom_category',
      '  :ARCHIVE_TODO: ',
      '  :END:',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
end)

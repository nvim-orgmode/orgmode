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

    vim.cmd([[exe "norm ,o$"]])
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
      '  :ARCHIVE_TIME: ' .. Date.now():to_string(),
      '  :ARCHIVE_FILE: ' .. file.filename,
      '  :ARCHIVE_CATEGORY: ' .. file:get_category(),
      '  :ARCHIVE_TODO: ',
      '  :END:',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
end)

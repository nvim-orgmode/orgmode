local helpers = require('tests.plenary.helpers')
local Date = require('orgmode.objects.date')

describe('Agenda visual archive', function()
  it('should archive multiple selected headlines in visual mode', function()
    local today = Date.now()
    local file = helpers.create_agenda_file({
      '* TODO headline 1',
      '    SCHEDULED: <2026-03-15 Sun>',
      '* TODO headline 2',
      '    SCHEDULED: <2026-03-15 Sun>',
      '* TODO headline 3',
      '    SCHEDULED: <2026-03-15 Sun>',
    })

    local org = require('orgmode')
    org.agenda:open_view('agenda', { files = org.files })

    vim.wait(100, function()
      return vim.api.nvim_buf_get_name(0):match('agenda')
    end)

    vim.fn.cursor(5, 1)
    vim.cmd('normal! V')
    vim.cmd('normal! jj')

    vim.wait(50)

    org.agenda:archive_visual()

    vim.wait(100)

    local archive_lines = vim.fn.readfile(file.filename .. '_archive')
    local content = table.concat(archive_lines, '\n')
    assert.is_not_nil(content:match('headline 1'), 'Archive should contain headline 1')
    assert.is_not_nil(content:match('headline 2'), 'Archive should contain headline 2')
    assert.is_not_nil(content:match('headline 3'), 'Archive should contain headline 3')
  end)

  it('should toggle ARCHIVE tag on multiple selected headlines in visual mode', function()
    local today = Date.now()
    local file = helpers.create_agenda_file({
      '* TODO headline 1',
      '    SCHEDULED: <2026-03-15 Sun>',
      '* TODO headline 2',
      '    SCHEDULED: <2026-03-15 Sun>',
      '* TODO headline 3',
      '    SCHEDULED: <2026-03-15 Sun>',
    })

    local org = require('orgmode')
    org.agenda:open_view('agenda', { files = org.files })

    vim.wait(100, function()
      return vim.api.nvim_buf_get_name(0):match('agenda')
    end)

    vim.fn.cursor(5, 1)
    vim.cmd('normal! V')
    vim.cmd('normal! jj')

    vim.wait(50)

    org.agenda:toggle_archive_tag_visual()

    vim.wait(100)

    local lines = vim.fn.readfile(file.filename)
    local content = table.concat(lines, '\n')
    assert.is_not_nil(content:match('headline 1.*:ARCHIVE:'), 'Headline 1 should have ARCHIVE tag')
    assert.is_not_nil(content:match('headline 2.*:ARCHIVE:'), 'Headline 2 should have ARCHIVE tag')
    assert.is_not_nil(content:match('headline 3.*:ARCHIVE:'), 'Headline 3 should have ARCHIVE tag')
  end)
end)

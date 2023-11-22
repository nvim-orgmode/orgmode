local orgmode = require('orgmode')

describe('Config', function()
  local refile_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/refile.org'

  it('should parse an absolute archive location for a file', function()
    local org = orgmode.setup({
      org_agenda_files = vim.fn.getcwd() .. '/tests/plenary/fixtures/*',
      org_default_notes_file = refile_file,
      org_archive_location = vim.fn.getcwd() .. '/tests/plenary/fixtures/archive/%s_archive::',
    })
    local config = require('orgmode.config')
    assert.are.same(
      config:parse_archive_location(refile_file),
      vim.fn.getcwd() .. '/tests/plenary/fixtures/archive/refile.org_archive'
    )
  end)

  it('should parse a relative archive location for a file', function()
    local org = orgmode.setup({
      org_agenda_files = vim.fn.getcwd() .. '/tests/plenary/fixtures/*',
      org_default_notes_file = refile_file,
      org_archive_location = 'archives_relative/%s_archive::',
    })
    local config = require('orgmode.config')
    assert.are.same(
      config:parse_archive_location(refile_file),
      vim.fn.getcwd() .. '/tests/plenary/fixtures/archives_relative/refile.org_archive'
    )
  end)
end)

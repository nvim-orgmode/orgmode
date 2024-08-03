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

  it('should use the default key mapping when no override is provided', function()
    local org = orgmode.setup({})
    local config = require('orgmode.config')
    assert.are.same('g{', config:get_mappings('org').outline_up_heading.user_map)
  end)

  it('should use the provided key mapping when the override is provided as a string', function()
    local org = orgmode.setup({
      mappings = {
        org = {
          outline_up_heading = 'gouh',
        }
      }
    })
    local config = require('orgmode.config')
    assert.are.same('gouh', config:get_mappings('org').outline_up_heading.user_map)
  end)

  it('should use the provided key mapping when the override is provided as a table', function()
    local org = orgmode.setup({
      mappings = {
        org = {
          outline_up_heading = { 'gouh' },
        }
      }
    })
    local config = require('orgmode.config')
    assert.are.same({ 'gouh' }, config:get_mappings('org').outline_up_heading.user_map)
  end)
end)

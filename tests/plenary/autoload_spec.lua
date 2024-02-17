local orgmode = require('orgmode')

describe('Autoload', function()
  it('should autoload dependencies when requested', function()
    local org = orgmode.setup({
      org_agenda_files = vim.fn.getcwd() .. '/tests/plenary/fixtures/*',
      org_default_notes_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/refile.org',
    })
    assert.is.False(org.initialized)
    assert.is.Nil(rawget(org, 'files'))
    assert.is.Nil(rawget(org, 'agenda'))
    assert.is.Nil(rawget(org, 'capture'))
    assert.is.Nil(rawget(org, 'org_mappings'))
    org.files:all()
    assert.is.True(org.initialized)
    assert.is.Not.Nil(rawget(org, 'files'))
    assert.is.Not.Nil(rawget(org, 'agenda'))
    assert.is.Not.Nil(rawget(org, 'capture'))
    assert.is.Not.Nil(rawget(org, 'org_mappings'))
  end)
end)

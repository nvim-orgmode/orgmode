local orgmode = require('orgmode')

describe('Init', function()
  it('should initialize orgmode with empty defaults on load', function()
    local org = orgmode.setup({ org_agenda_files = '', org_default_notes_file = '' })
    org:init()
    assert.are.same({}, org.agenda.files)
  end)

  it('should load and parse files from folder', function()
    local org = orgmode.setup({
      org_agenda_files = vim.fn.getcwd()..'/tests/plenary/fixtures/*',
      org_default_notes_file = vim.fn.getcwd()..'/tests/plenary/fixtures/refile.org',
    })
    local todo_file = vim.fn.getcwd()..'/tests/plenary/fixtures/todo.org'
    local refile_file = vim.fn.getcwd()..'/tests/plenary/fixtures/refile.org'
    assert.is.Nil(org.agenda)
    assert.is.Nil(org.capture)
    org:init()
    vim.wait(10)
    assert.is.Not.Nil(org.agenda)
    assert.is.Not.Nil(org.capture)
    assert.are.same('todo', org.agenda.files[todo_file].category)
    assert.are.same(11, #org.agenda.files[todo_file].items)
    assert.are.same('refile', org.agenda.files[refile_file].category)
    assert.are.same(0, #org.agenda.files[refile_file].items)
  end)
end)

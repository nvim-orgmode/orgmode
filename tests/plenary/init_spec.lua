local orgmode = require('orgmode')

describe('Init', function()
  it('should initialize orgmode with empty defaults on load', function()
    local org = orgmode.setup({ org_agenda_files = '', org_default_notes_file = '' })
    assert.are.same({}, org.files)
  end)

  it('should load and parse files from folder', function()
    local org = orgmode.setup({
      org_agenda_files = vim.fn.getcwd()..'/tests/plenary/fixtures/*',
      org_default_notes_file = vim.fn.getcwd()..'/tests/plenary/fixtures/refile.org',
    })
    local todo_file = vim.fn.getcwd()..'/tests/plenary/fixtures/todo.org'
    local refile_file = vim.fn.getcwd()..'/tests/plenary/fixtures/refile.org'
    vim.wait(10)
    assert.is.Not.Nil(org.files[todo_file])
    assert.is.Not.Nil(org.files[refile_file])
    assert.are.same('todo', org.files[todo_file].category)
    assert.are.same(11, #org.files[todo_file].items)
    assert.are.same('refile', org.files[refile_file].category)
    assert.are.same(0, #org.files[refile_file].items)
  end)
end)

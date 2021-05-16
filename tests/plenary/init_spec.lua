local orgmode = require('orgmode')

describe('Init', function()
  it('should initialize orgmode with empty defaults on load', function()
    local org = orgmode.setup()
    assert.are.same({}, org.agendas)
    assert.are.same({}, org.files)
  end)

  it('should load agendas from folder', function()
    local org = orgmode.setup({
      org_agenda_files = vim.fn.getcwd()..'/tests/plenary/fixtures/*',
      org_default_notes_file = vim.fn.getcwd()..'/tests/plenary/fixtures/refile.org',
    })
    local todo_file = vim.fn.getcwd()..'/tests/plenary/fixtures/todo.org'
    local refile_file = vim.fn.getcwd()..'/tests/plenary/fixtures/refile.org'
    assert.are.same({ refile_file, todo_file }, org.files)
    vim.wait(10)
    assert.is.Not.Nil(org.agendas[todo_file])
    assert.is.Not.Nil(org.agendas[refile_file])
    assert.are.same('todo', org.agendas[todo_file].category)
    assert.are.same(11, #org.agendas[todo_file].items)
    assert.are.same('refile', org.agendas[refile_file].category)
    assert.are.same(0, #org.agendas[refile_file].items)
  end)
end)

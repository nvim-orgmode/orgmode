local orgmode = require('orgmode')

describe('Init', function()
  it('should load and parse files from folder', function()
    local org = orgmode.setup({
      org_agenda_files = vim.fn.getcwd()..'/tests/plenary/fixtures/*',
      org_default_notes_file = vim.fn.getcwd()..'/tests/plenary/fixtures/refile.org',
    })
    local todo_file = vim.fn.getcwd()..'/tests/plenary/fixtures/todo.org'
    local refile_file = vim.fn.getcwd()..'/tests/plenary/fixtures/refile.org'
    assert.is.Nil(org.files)
    assert.is.Nil(org.agenda)
    assert.is.Nil(org.capture)
    assert.is.Nil(org.org_mappings)
    org:init()
    vim.wait(10)
    assert.is.Not.Nil(org.files)
    assert.is.Not.Nil(org.agenda)
    assert.is.Not.Nil(org.capture)
    assert.is.Not.Nil(org.org_mappings)
    assert.are.same('todo', org.files:get(todo_file).category)
    assert.are.same(11, #org.files:get(todo_file).items)
    assert.are.same('refile', org.files:get(refile_file).category)
    assert.are.same(0, #org.files:get(refile_file).items)
    assert.are.same({ 'NESTED',  'OFFICE', 'PRIVATE', 'PROJECT', 'WORK' }, org.files:get_tags())
  end)
end)

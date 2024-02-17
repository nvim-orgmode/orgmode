local orgmode = require('orgmode')

describe('Init', function()
  it('should load and parse files from folder', function()
    local org = orgmode.setup({
      org_agenda_files = vim.fn.getcwd() .. '/tests/plenary/fixtures/*',
      org_default_notes_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/refile.org',
    })
    local todo_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/todo.org'
    local todo_archive_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/todo.org_archive'
    local refile_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/refile.org'
    local txt_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/text_notes.txt'
    assert.is.Nil(rawget(org, 'files'))
    assert.is.Nil(rawget(org, 'agenda'))
    assert.is.Nil(rawget(org, 'capture'))
    assert.is.Nil(rawget(org, 'org_mappings'))
    org:init()
    assert.is.Not.Nil(rawget(org, 'files'))
    assert.is.Not.Nil(rawget(org, 'agenda'))
    assert.is.Not.Nil(rawget(org, 'capture'))
    assert.is.Not.Nil(rawget(org, 'org_mappings'))
    assert.is.error(function()
      return org.files:get(txt_file)
    end)
    assert.are.same('todo', org.files:get(todo_file):get_category())
    assert.are.same(9, #org.files:get(todo_file):get_headlines())
    assert.are.same(false, org.files:get(todo_file):is_archive_file())
    assert.are.same('refile', org.files:get(refile_file):get_category())
    assert.are.same(0, #org.files:get(refile_file):get_headlines())
    assert.are.same(false, org.files:get(refile_file):is_archive_file())
    assert.are.same('todo', org.files:get(todo_archive_file):get_category())
    assert.are.same(1, #org.files:get(todo_archive_file):get_headlines_including_archived())
    assert.are.same(0, #org.files:get(todo_archive_file):get_headlines())
    assert.are.same(true, org.files:get(todo_archive_file):is_archive_file())
    assert.are.same({ 'NESTED', 'OFFICE', 'PRIVATE', 'PROJECT', 'WORK' }, org.files:get_tags())
  end)
end)

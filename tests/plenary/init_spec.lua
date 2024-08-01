local helpers = require('tests.plenary.helpers')
local orgmode = require('orgmode')

describe('Init', function()
  local org = orgmode.setup({
    org_agenda_files = vim.fn.getcwd() .. '/tests/plenary/fixtures/*',
    org_default_notes_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/refile.org',
  })
  local todo_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/todo.org'
  local todo_archive_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/todo.org_archive'
  local refile_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/refile.org'
  local txt_file = vim.fn.getcwd() .. '/tests/plenary/fixtures/text_notes.txt'
  it('should load and parse files from folder', function()
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

  it('should append files to paths', function()
    local fname = vim.fn.resolve(vim.fn.tempname() .. '.org')
    vim.fn.writefile({ '* Appended' }, fname)

    assert.is.Nil(org.files.files[fname])
    assert.are.same({}, org.files:find_headlines_by_title('Appended'))
    assert.are.same({ vim.fn.getcwd() .. '/tests/plenary/fixtures/*' }, org.files.paths)

    org.files:add_to_paths_sync(fname)
    assert.is.Not.Nil(org.files.files[fname])
    assert.are.same('Appended', org.files:find_headlines_by_title('Appended')[1]:get_title())
    assert.are.same({ vim.fn.getcwd() .. '/tests/plenary/fixtures/*', fname }, org.files.paths)

    org.files:add_to_paths_sync(todo_file)
    -- Existing file in path not appended to paths
    assert.are.same({ vim.fn.getcwd() .. '/tests/plenary/fixtures/*', fname }, org.files.paths)
  end)
end)

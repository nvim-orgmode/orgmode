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

  it('should load file and persist to files if it belongs to path', function()
    local fname = vim.fn.resolve(vim.fn.tempname() .. '.org')
    vim.fn.writefile({ '* Appended' }, fname)

    assert.is.Nil(org.files.files[fname])
    assert.are.same({}, org.files:find_headlines_by_title('Appended'))
    assert.are.same({ vim.fn.getcwd() .. '/tests/plenary/fixtures/*' }, org.files.paths)

    -- Not added because it does not belong to defined path
    org.files:load_file_sync(fname, { persist = true })
    assert.is.Nil(org.files.files[fname])

    org.files.all_files[todo_file] = nil
    org.files.files[todo_file] = nil

    org.files:load_file_sync(todo_file)

    -- Not added because persist was not provided
    assert.is.Nil(org.files.files[todo_file])
    assert.is.Not.Nil(org.files.all_files[todo_file])

    org.files.all_files[todo_file] = nil
    org.files.files[todo_file] = nil

    org.files:load_file_sync(todo_file, { persist = true })
    assert.is.Not.Nil(org.files.files[todo_file])
  end)

  it('should load a file as org file if it has correct filetype', function()
    local fname = vim.fn.resolve(vim.fn.tempname() .. '.txt')

    -- Behaves as text file
    vim.fn.writefile({ '* TODO Test' }, fname)
    vim.cmd('edit ' .. fname)
    assert.are.same('text', vim.api.nvim_get_option_value('filetype', { buf = vim.api.nvim_get_current_buf() }))
    vim.cmd('norm >>')
    assert.are.same({ '        * TODO Test' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    vim.cmd('bw!')

    -- Behaves as org file
    vim.fn.writefile({ '* TODO Test' }, fname)
    vim.cmd('edit ' .. fname)
    vim.cmd('set filetype=org')
    vim.cmd('norm >>')
    assert.are.same({ '** TODO Test' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
end)

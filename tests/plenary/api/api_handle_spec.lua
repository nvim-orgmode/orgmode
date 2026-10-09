local helpers = require('tests.plenary.helpers')
local api = require('orgmode.api')

describe('Api handles', function()
  ---@return OrgApiFile
  local cur_file = function()
    -- Wait for 1ms to ensure that the file is reloaded
    vim.wait(1)
    return api.current()
  end

  it('loads several files by a list of names', function()
    local first = helpers.create_agenda_file({ '* TODO First' })
    local second = helpers.create_agenda_file({ '* TODO Second' })

    local files = api.load({ first.filename, second.filename })
    local names = vim.tbl_map(function(file)
      return file.filename
    end, files)
    table.sort(names)
    local expected = { first.filename, second.filename }
    table.sort(expected)
    assert.are.same(expected, names)
  end)

  it('reloads the same headline after a headline was inserted above', function()
    helpers.create_file({
      '* TODO First',
      '* TODO Second',
    })
    local headline = cur_file().headlines[2]
    assert.are.same('Second', headline.title)

    vim.api.nvim_buf_set_lines(0, 0, 0, false, { '* TODO Inserted' })

    local reloaded = headline:reload()
    assert.are.same('Second', reloaded.title)
  end)

  it('applies a mutator to its own headline after lines were inserted above', function()
    helpers.create_file({
      '* TODO First',
      '* TODO Second',
    })
    local headline = cur_file().headlines[2]

    vim.api.nvim_buf_set_lines(0, 0, 0, false, { '* TODO Inserted' })

    headline:set_tags({ 'moved' }):wait()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same('* TODO Inserted', lines[1])
    assert.are.same('* TODO First', lines[2])
    assert.is.Not.Nil(lines[3]:match('^%* TODO Second%s+:moved:$'))
  end)

  it('applies a second mutator through the same handle', function()
    helpers.create_file({
      '* TODO First',
      '* TODO Second',
    })
    local headline = cur_file().headlines[2]

    headline:set_tags({ 'one' }):wait()
    headline:set_priority('A'):wait()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same('* TODO First', lines[1])
    assert.is.Not.Nil(lines[2]:match('^%* TODO %[#A%] Second%s+:one:$'))
  end)

  it('returns the same id when id_get_or_create is called twice on a handle', function()
    helpers.create_file({ '* TODO First' })
    local headline = cur_file().headlines[1]

    local first_id = headline:id_get_or_create()
    local second_id = headline:id_get_or_create()

    assert.are.same(first_id, second_id)
    assert.are.same(first_id, cur_file().headlines[1]:get_property('id'))
  end)

  it('clears a removed date on the handle', function()
    helpers.create_file({ '* TODO First' })
    local headline = cur_file().headlines[1]

    headline:set_deadline('2026-01-01'):wait()
    assert.is.Not.Nil(headline.deadline)
    headline:set_deadline(''):wait()
    assert.is.Nil(headline.deadline)
  end)

  it('raises an error instead of guessing between identical headlines after an edit', function()
    helpers.create_file({
      '* TODO Same',
      '* TODO Same',
    })
    local headline = cur_file().headlines[2]

    vim.api.nvim_buf_set_lines(0, 0, 0, false, { '* TODO Inserted' })

    assert.has.error(function()
      headline:set_tags({ 'x' })
    end)
    assert.are.same({ '* TODO Inserted', '* TODO Same', '* TODO Same' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('raises an error when the headline with its id was deleted', function()
    helpers.create_file({
      '* TODO Same',
      '  :PROPERTIES:',
      '  :ID: first-id',
      '  :END:',
      '* TODO Same',
      '  :PROPERTIES:',
      '  :ID: second-id',
      '  :END:',
    })
    local headline = cur_file().headlines[1]

    vim.api.nvim_buf_set_lines(0, 0, 4, false, {})

    assert.has.error(function()
      headline:set_tags({ 'x' })
    end)
    assert.are.same(
      { '* TODO Same', '  :PROPERTIES:', '  :ID: second-id', '  :END:' },
      vim.api.nvim_buf_get_lines(0, 0, -1, false)
    )
  end)

  it('raises an error when two headlines share the id of the handle', function()
    helpers.create_file({
      '* TODO First',
      '  :PROPERTIES:',
      '  :ID: same-id',
      '  :END:',
      '* TODO Second',
      '  :PROPERTIES:',
      '  :ID: same-id',
      '  :END:',
    })
    local headline = cur_file().headlines[2]

    assert.has.error(function()
      headline:set_tags({ 'x' })
    end)
    assert.are.same('* TODO First', vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
  end)

  it('keeps handles of identical headlines valid after the file changed on disk under unsaved edits', function()
    local file = helpers.create_file({
      '* TODO Same',
      '* TODO Same',
    })
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'unsaved body' })
    vim.wait(10)
    vim.fn.writefile({ '* TODO Same', '* TODO Same' }, file.filename)
    local headline = cur_file().headlines[2]

    headline:set_tags({ 'x' }):wait()

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same('* TODO Same', lines[1])
    assert.is.Not.Nil(lines[2]:match('^%* TODO Same%s+:x:$'))
    assert.are.same('unsaved body', lines[3])
  end)

  it('keeps a handle valid when the file changes on disk after the handle was built', function()
    local file = helpers.create_file({
      '* TODO Same',
      '* TODO Same',
    })
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'unsaved body' })
    local headline = cur_file().headlines[2]
    vim.wait(10)
    vim.fn.writefile({ '* TODO Same', '* TODO Same' }, file.filename)

    headline:set_tags({ 'x' }):wait()

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same('* TODO Same', lines[1])
    assert.is.Not.Nil(lines[2]:match('^%* TODO Same%s+:x:$'))
    assert.are.same('unsaved body', lines[3])
  end)

  it('reads the file from disk after its buffer is unloaded when the file changed while it was loaded', function()
    local target = helpers.create_agenda_file({ '* TODO Old' })
    local target_bufnr = vim.fn.bufnr(target.filename)
    api.load(target.filename)
    vim.wait(10)
    vim.fn.writefile({ '* TODO New' }, target.filename)
    api.load(target.filename)

    vim.cmd('bwipeout ' .. target_bufnr)

    assert.are.same('New', api.load(target.filename).headlines[1].title)
  end)

  it('reads the file from disk after its buffer is unloaded with unsaved edits discarded', function()
    local target = helpers.create_agenda_file({ '* TODO Saved' })
    local target_bufnr = vim.fn.bufnr(target.filename)
    vim.api.nvim_buf_set_lines(target_bufnr, 0, -1, false, { '* TODO Unsaved' })
    api.load(target.filename)

    vim.cmd('bwipeout! ' .. target_bufnr)

    assert.are.same('Saved', api.load(target.filename).headlines[1].title)
  end)

  it('acts on its own headline after the buffer is replaced with text changed on disk', function()
    local file = helpers.create_file({ '* TODO Target' })
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { '* TODO Inserted' })
    cur_file()
    vim.wait(10)
    vim.fn.writefile({ '* TODO Target', '* TODO Other' }, file.filename)
    local headline = cur_file().headlines[2]
    vim.cmd('silent edit!')

    headline:set_tags({ 'x' }):wait()

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.is.Not.Nil(lines[1]:match('^%* TODO Target%s+:x:$'))
    assert.are.same('* TODO Other', lines[2])
  end)

  it('keeps handles of identical headlines valid after writing the unchanged file', function()
    helpers.create_file({
      '* TODO Same',
      '* TODO Same',
    })
    local headline = cur_file().headlines[2]

    vim.wait(10)
    vim.cmd('silent write')

    headline:set_tags({ 'x' }):wait()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same('* TODO Same', lines[1])
    assert.is.Not.Nil(lines[2]:match('^%* TODO Same%s+:x:$'))
  end)

  it('builds handles from the current buffer text when loading a list of files', function()
    local target = helpers.create_agenda_file({
      '* TODO Same',
      '* TODO Same',
    })
    local target_bufnr = vim.fn.bufnr(target.filename)
    vim.api.nvim_buf_set_lines(target_bufnr, 0, 0, false, { '* TODO Inserted' })

    api.load({ target.filename })[1].headlines[3]:set_tags({ 'x' }):wait()

    local lines = vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false)
    assert.are.same('* TODO Same', lines[2])
    assert.is.Not.Nil(lines[3]:match('^%* TODO Same%s+:x:$'))
  end)

  it('does not write unrelated unsaved edits to disk on an api mutation', function()
    -- Assumption: an API call may save its own change, but it must not
    -- persist edits the user has not saved yet. Here the unsaved edit is
    -- an extra paragraph; it must stay out of the file on disk.
    local file = helpers.create_file({
      '* TODO First',
      '* TODO Second',
    })
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'unsaved user edit' })
    assert.is.True(vim.bo.modified)

    cur_file().headlines[1]:set_tags({ 'api' }):wait()

    local on_disk = vim.fn.readfile(file.filename)
    assert.is.False(vim.tbl_contains(on_disk, 'unsaved user edit'))
  end)

  it('keeps unsaved edits in a hidden buffer out of the file on an api mutation', function()
    local target = helpers.create_agenda_file({ '* TODO Target' })
    local target_bufnr = vim.fn.bufnr(target.filename)
    vim.api.nvim_buf_set_lines(target_bufnr, -1, -1, false, { 'unsaved user edit' })
    helpers.create_file({ '* TODO Other buffer' })

    api.load(target.filename).headlines[1]:set_tags({ 'api' }):wait()

    local on_disk = vim.fn.readfile(target.filename)
    assert.is.False(vim.tbl_contains(on_disk, 'unsaved user edit'))
    local in_buffer = vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false)
    assert.is.Not.Nil(in_buffer[1]:match('^%* TODO Target%s+:api:$'))
    assert.are.same('unsaved user edit', in_buffer[2])
  end)

  it('has the id property set once id_get_or_create returns for a file not in the current buffer', function()
    local target = helpers.create_agenda_file({
      '* TODO Target',
    })
    local target_name = target.filename
    helpers.create_file({ '* TODO Other buffer' })

    local headline = api.load(target_name).headlines[1]
    local id = headline:id_get_or_create()

    local on_disk = vim.fn.readfile(target_name)
    assert.is.Not.Nil(table.concat(on_disk, '\n'):find(id, 1, true))
  end)
end)

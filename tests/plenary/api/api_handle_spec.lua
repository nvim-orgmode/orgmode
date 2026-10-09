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

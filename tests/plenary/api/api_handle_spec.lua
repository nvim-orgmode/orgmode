local helpers = require('tests.plenary.helpers')
local api = require('orgmode.api')
local config = require('orgmode.config')

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

  it('loads a file by a list of names that holds a symlink to it', function()
    local target = helpers.create_agenda_file({ '* TODO Target' })
    local link = vim.fn.tempname() .. '-link.org'
    vim.uv.fs_symlink(target.filename, link)

    local files = api.load({ link })
    vim.fn.delete(link)

    assert.are.same(
      { target.filename },
      vim.tbl_map(function(file)
        return file.filename
      end, files)
    )
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

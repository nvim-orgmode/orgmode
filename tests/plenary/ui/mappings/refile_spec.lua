local helpers = require('tests.plenary.helpers')
local org = require('orgmode')

describe('Refile mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should refile to headline that matches name exactly', function()
    local destination_file = helpers.load_file_content({
      '* foobar',
      '* baz',
      '** foo',
    })

    local source_file = helpers.load_file_content({
      '* to be refiled',
      '* not to be refiled',
    })

    source_file = org.files:get_current_file()
    local item = source_file:get_closest_headline()
    org.capture:_refile_to({
      file = destination_file,
      lines = item:get_lines(),
      item = item,
      headline = 'foo',
    })
    assert.are.same('* not to be refiled', vim.fn.getline(1))
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file))
    assert.are.same({
      '* foobar',
      '* baz',
      '** foo',
      '*** to be refiled',
    }, vim.api.nvim_buf_get_lines(0, 0, 5, false))
  end)

  it('should refile to headline and properly demote', function()
    local destination_file = helpers.load_file_content({
      '* foobar',
      '* baz',
      '** foo',
    })

    local source_file = helpers.load_file_content({
      '* to be refiled',
      '* not to be refiled',
    })

    source_file = org.files:get_current_file()
    local item = source_file:get_closest_headline()
    org.capture:_refile_to({
      file = destination_file,
      lines = item:get_lines(),
      item = item,
      headline = 'foobar',
    })
    assert.are.same('* not to be refiled', vim.fn.getline(1))
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file))
    assert.are.same({
      '* foobar',
      '** to be refiled',
      '* baz',
      '** foo',
    }, vim.api.nvim_buf_get_lines(0, 0, 5, false))
  end)

  it('should refile to headline and properly promote', function()
    local destination_file = helpers.load_file_content({
      '* foobar',
      '* baz',
      '** foo',
    })

    local source_file = helpers.load_file_content({
      '**** to be refiled',
      '* not to be refiled',
    })

    source_file = org.files:get_current_file()
    local item = source_file:get_closest_headline()
    org.capture:_refile_to({
      file = destination_file,
      lines = item:get_lines(),
      item = item,
      headline = 'foobar',
    })
    assert.are.same('* not to be refiled', vim.fn.getline(1))
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file))
    assert.are.same({
      '* foobar',
      '** to be refiled',
      '* baz',
      '** foo',
    }, vim.api.nvim_buf_get_lines(0, 0, 5, false))
  end)
end)

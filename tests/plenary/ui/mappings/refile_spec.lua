local helpers = require('tests.plenary.helpers')
local org = require('orgmode')

describe('Refile mappings', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should refile to headline that matches name exactly', function()
    local destination_file = helpers.create_file({
      '* foobar',
      '* baz',
      '** foo',
    })

    local source_file = helpers.create_file({
      '* to be refiled',
      '* not to be refiled',
    })

    local item = source_file:get_closest_headline()
    org.capture:process_refile({
      destination_file = destination_file,
      source_file = source_file,
      source_headline = item,
      destination_headline = destination_file:get_headlines()[3],
    })
    assert.are.same('* not to be refiled', vim.fn.getline(1))
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file.filename))
    assert.are.same({
      '* foobar',
      '* baz',
      '** foo',
      '*** to be refiled',
    }, vim.api.nvim_buf_get_lines(0, 0, 5, false))
  end)

  it('should refile to headline and properly demote', function()
    local destination_file = helpers.create_file({
      '* foobar',
      '* baz',
      '** foo',
    })

    local source_file = helpers.create_file({
      '* to be refiled',
      '* not to be refiled',
    })

    local item = source_file:get_closest_headline()
    org.capture:process_refile({
      destination_file = destination_file,
      source_file = source_file,
      source_headline = item,
      destination_headline = destination_file:get_headlines()[1],
    })
    assert.are.same('* not to be refiled', vim.fn.getline(1))
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file.filename))
    assert.are.same({
      '* foobar',
      '** to be refiled',
      '* baz',
      '** foo',
    }, vim.api.nvim_buf_get_lines(0, 0, 5, false))
  end)

  it('should refile to headline and properly promote', function()
    local destination_file = helpers.create_file({
      '* foobar',
      '* baz',
      '** foo',
    })

    local source_file = helpers.create_file({
      '**** to be refiled',
      '* not to be refiled',
    })

    local item = source_file:get_closest_headline()
    org.capture:process_refile({
      destination_file = destination_file,
      source_file = source_file,
      source_headline = item,
      destination_headline = destination_file:get_headlines()[1],
    })
    assert.are.same('* not to be refiled', vim.fn.getline(1))
    vim.cmd('edit' .. vim.fn.fnameescape(destination_file.filename))
    assert.are.same({
      '* foobar',
      '** to be refiled',
      '* baz',
      '** foo',
    }, vim.api.nvim_buf_get_lines(0, 0, 5, false))
  end)
end)

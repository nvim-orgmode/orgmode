local helpers = require('tests.plenary.helpers')

describe('Visual promote/demote', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should promote multiple selected headings in visual mode', function()
    helpers.create_file({
      '* TODO Test heading 1',
      '* TODO Test heading 2',
      '* TODO Test heading 3',
    })

    vim.fn.cursor(1, 1)
    vim.cmd('normal! V')
    vim.cmd('normal! jj')

    local org = require('orgmode')
    org.action('org_mappings.do_promote_visual')

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({
      'TODO Test heading 1',
      'TODO Test heading 2',
      'TODO Test heading 3',
    }, lines)
  end)

  it('should demote multiple selected headings in visual mode', function()
    helpers.create_file({
      '* TODO Test heading 1',
      '* TODO Test heading 2',
      '* TODO Test heading 3',
    })

    vim.fn.cursor(1, 1)
    vim.cmd('normal! V')
    vim.cmd('normal! jj')

    local org = require('orgmode')
    org.action('org_mappings.do_demote_visual')

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({
      '** TODO Test heading 1',
      '** TODO Test heading 2',
      '** TODO Test heading 3',
    }, lines)
  end)

  it('should promote mixed content (heading and non-heading)', function()
    helpers.create_file({
      'some plain text',
      '* TODO Test heading 2',
      'another plain text',
    })

    vim.fn.cursor(1, 1)
    vim.cmd('normal! V')
    vim.cmd('normal! jj')

    local org = require('orgmode')
    org.action('org_mappings.do_promote_visual')

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({
      'some plain text',
      'TODO Test heading 2',
      'another plain text',
    }, lines)
  end)

  it('should demote mixed content (heading and non-heading)', function()
    helpers.create_file({
      'some plain text',
      '* TODO Test heading 2',
      'another plain text',
    })

    vim.fn.cursor(1, 1)
    vim.cmd('normal! V')
    vim.cmd('normal! jj')

    local org = require('orgmode')
    org.action('org_mappings.do_demote_visual')

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({
      'some plain text',
      '** TODO Test heading 2',
      'another plain text',
    }, lines)
  end)

  it('should handle multiple levels of headings correctly', function()
    helpers.create_file({
      '* Level 1 heading',
      '** Level 2 heading',
      '*** Level 3 heading',
    })

    vim.fn.cursor(1, 1)
    vim.cmd('normal! V')
    vim.cmd('normal! jj')

    local org = require('orgmode')
    org.action('org_mappings.do_promote_visual')

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({
      'Level 1 heading',
      '* Level 2 heading',
      '** Level 3 heading',
    }, lines)
  end)

  it('should fallback to default behavior when selection has no headline on promote', function()
    helpers.create_file({
      'plain text line 1',
      'plain text line 2',
      'plain text line 3',
    })

    vim.fn.cursor(1, 1)
    vim.cmd('normal! V')
    vim.cmd('normal! jj')

    local org = require('orgmode')
    org.action('org_mappings.do_promote_visual')

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({
      'plain text line 1',
      'plain text line 2',
      'plain text line 3',
    }, lines)
  end)

  it('should fallback to default behavior when selection has no headline on demote', function()
    helpers.create_file({
      'plain text line 1',
      'plain text line 2',
      'plain text line 3',
    })

    vim.fn.cursor(1, 1)
    vim.cmd('normal! V')
    vim.cmd('normal! jj')

    local org = require('orgmode')
    org.action('org_mappings.do_demote_visual')

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({
      '        plain text line 1',
      '        plain text line 2',
      '        plain text line 3',
    }, lines)
  end)
end)

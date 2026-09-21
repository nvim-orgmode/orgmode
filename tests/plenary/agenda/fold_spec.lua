local helpers = require('tests.plenary.helpers')
local orgmode = require('orgmode')

describe('Agenda block folds', function()
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  local function setup(custom_commands)
    helpers.create_agenda_file({
      '* TODO First task :work:',
      '* TODO Second task :work:',
      '* TODO Third task :home:',
    }, {
      org_agenda_custom_commands = custom_commands,
    })
  end

  local two_blocks = {
    x = {
      description = 'Two blocks',
      types = {
        {
          type = 'tags_todo',
          match = '+work',
          org_agenda_overriding_header = 'Block A',
        },
        {
          type = 'tags_todo',
          match = '+home',
          org_agenda_overriding_header = 'Block B',
        },
      },
    },
    y = {
      description = 'One block',
      types = {
        {
          type = 'tags_todo',
          match = '+work',
          org_agenda_overriding_header = 'Only block',
        },
      },
    },
  }

  local function find_line(text)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for lnum, line in ipairs(lines) do
      if line == text then
        return lnum
      end
    end
    error('Line not found: ' .. text)
  end

  local function press_tab()
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<TAB>', true, false, true), 'x', false)
  end

  it('folds every block of a multi block agenda including the separator', function()
    setup(two_blocks)
    orgmode.agenda:open_by_key('x'):wait()

    assert.are.same('expr', vim.wo.foldmethod)
    local header_a = find_line('Block A')
    local header_b = find_line('Block B')
    assert.are.same(1, header_a)
    assert.are.same(5, header_b)
    assert.are.same(6, vim.api.nvim_buf_line_count(0))
    assert.are.same('', vim.fn.getline(4))

    for lnum = 1, vim.api.nvim_buf_line_count(0) do
      assert.are.same(1, vim.fn.foldlevel(lnum), 'fold level of line ' .. lnum)
      assert.are.same(-1, vim.fn.foldclosed(lnum), 'line ' .. lnum .. ' closed on open')
    end

    vim.cmd(('%dfoldclose'):format(header_a))
    assert.are.same(header_a, vim.fn.foldclosed(header_a))
    assert.are.same(header_b - 1, vim.fn.foldclosedend(header_a))
    assert.are.same(-1, vim.fn.foldclosed(header_b))
  end)

  it('does not fold a single block agenda', function()
    setup(two_blocks)
    orgmode.agenda:open_by_key('y'):wait()

    find_line('Only block')
    for lnum = 1, vim.api.nvim_buf_line_count(0) do
      assert.are.same(0, vim.fn.foldlevel(lnum), 'fold level of line ' .. lnum)
    end
  end)

  it('keeps closed and open blocks after redo', function()
    setup(two_blocks)
    orgmode.agenda:open_by_key('x'):wait()
    local header_a = find_line('Block A')
    local header_b = find_line('Block B')

    vim.cmd(('%dfoldclose'):format(header_a))
    orgmode.agenda:redo():wait()
    assert.are.same(header_a, vim.fn.foldclosed(header_a))
    assert.are.same(-1, vim.fn.foldclosed(header_b))

    vim.cmd('normal! zM')
    vim.cmd(('%dfoldopen'):format(header_a))
    orgmode.agenda:redo():wait()
    assert.are.same(-1, vim.fn.foldclosed(header_a))
    assert.are.same(header_b, vim.fn.foldclosed(header_b))
  end)

  it('toggles the block with <TAB> on its header and opens the item elsewhere', function()
    setup(two_blocks)
    orgmode.agenda:open_by_key('x'):wait()
    local header_a = find_line('Block A')

    vim.fn.cursor({ header_a, 0 })
    press_tab()
    assert.are.same(header_a, vim.fn.foldclosed(header_a))
    assert.are.same('orgagenda', vim.bo.filetype)

    press_tab()
    assert.are.same(-1, vim.fn.foldclosed(header_a))

    vim.fn.cursor({ header_a + 1, 0 })
    press_tab()
    assert.are.same('org', vim.bo.filetype)
    assert.are.same('* TODO First task :work:', vim.fn.getline('.'))
  end)
end)

local helpers = require('tests.plenary.helpers')
local Date = require('orgmode.objects.date')

describe('Clock', function()
  local files = {}
  after_each(function()
    vim.cmd([[silent! %bw!]])
  end)

  it('should clock in and clock out an entry', function()
    local first_file = helpers.create_agenda_file({
      '#TITLE: First file',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    table.insert(files, first_file.filename)
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,oxi]])
    vim.wait(0)
    local now = Date.now({ active = false }):to_wrapped_string()
    assert.are.same('  :LOGBOOK:', vim.fn.getline(5))
    assert.are.same(string.format('  CLOCK: %s', now), vim.fn.getline(6))
    assert.are.same('  :END:', vim.fn.getline(7))
    assert.are.same('(Org) [0:00] (Test orgmode)', require('orgmode').action('clock.get_statusline'))

    vim.fn.cursor(3, 1)
    local new_now = Date.now({ active = false }):to_wrapped_string()
    vim.cmd([[norm ,oxo]])
    assert.are.same('  :LOGBOOK:', vim.fn.getline(5))
    assert.are.same(string.format('  CLOCK: %s--%s => 0:00', now, new_now), vim.fn.getline(6))
    assert.are.same('  :END:', vim.fn.getline(7))
    assert.are.same('', require('orgmode').action('clock.get_statusline'))
    vim.cmd([[silent! write!]])
  end)

  it('should clock out first entry from same file once second entry is clocked in', function()
    local second_file = helpers.create_agenda_file({
      '#TITLE: Second file',
      '',
      '* TODO First clocked in',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '  :PROPERTIES:',
      '  :Effort: 2:00',
      '  :END:',
      '* TODO Second clocked in',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
      '',
    })
    table.insert(files, second_file.filename)

    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,oxi]])
    vim.wait(0) -- wait for promise to fulfill
    local now = Date.now({ active = false }):to_wrapped_string()
    assert.are.same('  :LOGBOOK:', vim.fn.getline(8))
    assert.are.same(string.format('  CLOCK: %s', now), vim.fn.getline(9))
    assert.are.same('  :END:', vim.fn.getline(10))
    assert.are.same('(Org) [0:00/2:00] (First clocked in)', require('orgmode').action('clock.get_statusline'))

    vim.fn.cursor(11, 1)
    local new_now = Date.now({ active = false }):to_wrapped_string()
    vim.cmd([[norm ,oxi]])
    vim.wait(0) -- wait for promise to fulfill
    -- First clocked out
    assert.are.same('  :LOGBOOK:', vim.fn.getline(8))
    assert.are.same(string.format('  CLOCK: %s--%s => 0:00', now, new_now), vim.fn.getline(9))
    assert.are.same('  :END:', vim.fn.getline(10))

    -- Second clocked in
    assert.are.same('  :LOGBOOK:', vim.fn.getline(13))
    assert.are.same(string.format('  CLOCK: %s', new_now), vim.fn.getline(14))
    assert.are.same('  :END:', vim.fn.getline(15))
    vim.cmd([[silent! write!]])
    assert.are.same('(Org) [0:00] (Second clocked in)', require('orgmode').action('clock.get_statusline'))
  end)

  it('should clock out entry from another file once entry is clocked in', function()
    local third_file = helpers.create_agenda_file({
      '#TITLE: Third file',
      '',
      '* TODO Third file headline',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })

    table.insert(files, third_file.filename)
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,oxi]])
    vim.wait(0) -- wait for promise to fulfill
    local now = Date.now({ active = false }):to_wrapped_string()
    assert.are.same('  :LOGBOOK:', vim.fn.getline(5))
    assert.are.same(string.format('  CLOCK: %s', now), vim.fn.getline(6))
    assert.are.same('  :END:', vim.fn.getline(7))
    vim.cmd([[silent! write!]])

    -- Second clocked out
    vim.cmd.edit(files[2])
    assert.are.same('  :LOGBOOK:', vim.fn.getline(13))
    assert.are.same(string.format('  CLOCK: %s--%s => 0:00', now, now), vim.fn.getline(14))
    assert.are.same('  :END:', vim.fn.getline(15))
    vim.cmd.edit(third_file.filename)
    assert.are.same('(Org) [0:00] (Third file headline)', require('orgmode').action('clock.get_statusline'))
  end)

  it('should jump to the clocked out headline from anywhere', function()
    vim.cmd.edit(files[1])
    assert.are.same(files[1], vim.api.nvim_buf_get_name(0))
    vim.cmd([[norm ,oxj]])
    assert.are.same(files[3], vim.api.nvim_buf_get_name(0))
    assert.are.same(3, vim.fn.line('.'))
  end)

  it('should cancel the active clock and remove the clock entry from logbook', function()
    vim.cmd.edit(files[1])
    local old_clock_line = vim.fn.getline(6)
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,oxi]])
    vim.wait(0) -- wait for promise to fulfill
    local now = Date.now({ active = false }):to_wrapped_string()
    assert.are.same('  :LOGBOOK:', vim.fn.getline(5))
    assert.are.same(string.format('  CLOCK: %s', now), vim.fn.getline(6))
    assert.are.same(old_clock_line, vim.fn.getline(7))
    assert.are.same('  :END:', vim.fn.getline(8))
    assert.are.same('(Org) [0:00] (Test orgmode)', require('orgmode').action('clock.get_statusline'))
    vim.cmd([[norm ,oxq]])
    assert.are.same('  :LOGBOOK:', vim.fn.getline(5))
    assert.are.same(old_clock_line, vim.fn.getline(6))
    assert.are.same('  :END:', vim.fn.getline(7))
    assert.are.same('', require('orgmode').action('clock.get_statusline'))
  end)

  it('should remove the whole logbook drawer when canceling single clock entry', function()
    helpers.create_file({
      '#TITLE: Clocked file',
      '',
      '* TODO Test orgmode',
      '  DEADLINE: <2021-07-21 Wed 22:02>',
    })
    vim.fn.cursor(3, 1)
    vim.cmd([[norm ,oxi]])
    vim.wait(0) -- wait for promise to fulfill
    local now = Date.now({ active = false }):to_wrapped_string()
    assert.are.same('  :LOGBOOK:', vim.fn.getline(5))
    assert.are.same(string.format('  CLOCK: %s', now), vim.fn.getline(6))
    assert.are.same('  :END:', vim.fn.getline(7))
    vim.cmd([[norm ,oxq]])
    assert.are.same(4, vim.fn.line('$'))
    assert.are.same('', vim.fn.getline(5))
    assert.are.same('', vim.fn.getline(6))
    assert.are.same('', vim.fn.getline(7))
  end)
end)

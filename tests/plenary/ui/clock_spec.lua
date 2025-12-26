local helpers = require('tests.plenary.helpers')
local Date = require('orgmode.objects.date')
local orgmode = require('orgmode')

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
    local now = Date.now({ active = false }):to_wrapped_string()
    vim.cmd([[norm ,oxi]])
    vim.wait(100)
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
    local now = Date.now({ active = false }):to_wrapped_string()
    vim.cmd([[norm ,oxi]])
    vim.wait(100) -- wait for promise to fulfill
    assert.are.same('  :LOGBOOK:', vim.fn.getline(8))
    assert.are.same(string.format('  CLOCK: %s', now), vim.fn.getline(9))
    assert.are.same('  :END:', vim.fn.getline(10))
    assert.are.same('(Org) [0:00/2:00] (First clocked in)', require('orgmode').action('clock.get_statusline'))

    vim.fn.cursor(11, 1)
    local new_now = Date.now({ active = false }):to_wrapped_string()
    vim.cmd([[norm ,oxi]])
    vim.wait(100) -- wait for promise to fulfill
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
    local now = Date.now({ active = false }):to_wrapped_string()
    vim.cmd([[norm ,oxi]])
    vim.wait(100) -- wait for promise to fulfill
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
    local now = Date.now({ active = false }):to_wrapped_string()
    vim.cmd([[norm ,oxi]])
    vim.wait(100) -- wait for promise to fulfill
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
    local now = Date.now({ active = false }):to_wrapped_string()
    vim.cmd([[norm ,oxi]])
    vim.wait(100) -- wait for promise to fulfill
    assert.are.same('  :LOGBOOK:', vim.fn.getline(5))
    assert.are.same(string.format('  CLOCK: %s', now), vim.fn.getline(6))
    assert.are.same('  :END:', vim.fn.getline(7))
    vim.cmd([[norm ,oxq]])
    assert.are.same(4, vim.fn.line('$'))
    assert.are.same('', vim.fn.getline(5))
    assert.are.same('', vim.fn.getline(6))
    assert.are.same('', vim.fn.getline(7))
  end)

  it('should properly clock in an entry if unsaved edits were made to the buffer', function()
    local file = helpers.create_agenda_file({
      '* TODO Test 1',
      '  :LOGBOOK:',
      '  CLOCK: [2024-05-22 Wed 05:15]',
      '  :END:',
      '* TODO Test 2',
    })

    vim.cmd('edit ' .. file.filename)

    -- Establish baseline: Test 1 is clocked in
    local clock = orgmode.clock
    assert.is_true(clock:has_clocked_headline()) -- Triggers lazy init
    assert.are.same('Test 1', clock.clocked_headline:get_title())
    assert.is_true(clock.clocked_headline:is_clocked_in())

    -- Move the test 2 header above test 1 and then clock test 2 in
    vim.fn.cursor({ 5, 1 })
    vim.cmd([[norm dd]])
    vim.fn.cursor({ 1, 1 })
    vim.cmd([[norm P]])
    vim.fn.cursor({ 1, 1 })
    clock:org_clock_in():wait()
    file:reload():wait()

    -- Test 2 is properly clocked in
    assert.are.same('Test 2', clock.clocked_headline:get_title())
    assert.are.same('Test 2', file:get_headlines()[1]:get_title())
    assert.is_true(file:get_headlines()[1]:is_clocked_in())

    -- Test 1 is properly clocked out
    assert.are.same('Test 1', file:get_headlines()[2]:get_title())
    assert.is_false(file:get_headlines()[2]:is_clocked_in())
  end)

  it('should clock out and entry when its marked as done', function()
    local file = helpers.create_agenda_file({
      '* TODO Test 1',
      '  Content',
      '* TODO Test 2',
      '  :LOGBOOK:',
      '  CLOCK: ' .. Date.now():to_wrapped_string(false),
      '  :END:',
      '* TODO Test 3',
    })

    vim.cmd('edit ' .. file.filename)
    vim.fn.cursor({ 3, 1 })
    vim.cmd([[norm cit]])
    assert.are.same({
      '* TODO Test 1',
      '  Content',
      '* DONE Test 2',
      '  CLOSED: ' .. Date.now():to_wrapped_string(false),
      '  :LOGBOOK:',
      '  CLOCK: ' .. Date.now():to_wrapped_string(false) .. '--' .. Date.now():to_wrapped_string(false) .. ' => 0:00',
      '  :END:',
      '* TODO Test 3',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  describe('async preload', function()
    it('should preload clocked headline after files are loaded', function()
      local file = helpers.create_agenda_file({
        '* TODO Test headline',
        '  :LOGBOOK:',
        '  CLOCK: [2024-05-22 Wed 05:15]',
        '  :END:',
      })
      vim.cmd('edit ' .. file.filename)

      local clock = orgmode.clock
      -- Async preload runs in background - wait for it to complete
      vim.wait(1000, function()
        return clock.clocked_headline ~= nil
      end, 10)

      assert.is_true(clock._clocked_headline_searched)
      assert.is_not_nil(clock.clocked_headline)

      -- Multiple calls are idempotent
      local result1 = clock:has_clocked_headline()
      local result2 = clock:has_clocked_headline()
      assert.is_true(clock._clocked_headline_searched)
      assert.is_true(result1)
      assert.is_true(result2)
    end)

    it('should return consistent results after async preload', function()
      local file = helpers.create_agenda_file({
        '* TODO Clocked task',
        '  :LOGBOOK:',
        '  CLOCK: [2024-05-22 Wed 05:15]',
        '  :END:',
      })
      vim.cmd('edit ' .. file.filename)

      local clock = orgmode.clock
      -- Trigger lazy init via has_clocked_headline
      local first_result = clock:has_clocked_headline()
      local first_headline = clock.clocked_headline

      -- Call again - should get same result
      local second_result = clock:has_clocked_headline()
      local second_headline = clock.clocked_headline

      assert.are.equal(first_result, second_result)
      assert.are.same(first_headline:get_title(), second_headline:get_title())
    end)

    it('should not search before files are loaded', function()
      local Clock = require('orgmode.clock')
      -- Create a mock files object that isn't loaded
      local mock_files = {
        load_state = 'loading', -- Not 'loaded'
        get_clocked_headline = function()
          error('Should not be called when files not loaded')
        end,
      }

      local clock = Clock:new({ files = mock_files })
      assert.is_false(clock._clocked_headline_searched)

      -- Call _ensure_clocked_headline_searched directly
      clock:_ensure_clocked_headline_searched()

      -- Should still be false - didn't search because files not loaded
      assert.is_false(clock._clocked_headline_searched)
      assert.is_nil(clock.clocked_headline)
    end)

    it('should search when files are loaded', function()
      local Clock = require('orgmode.clock')
      local search_called = false
      -- Create a mock files object that is loaded
      local mock_files = {
        load_state = 'loaded',
        get_clocked_headline = function()
          search_called = true
          return nil
        end,
      }

      local clock = Clock:new({ files = mock_files })
      assert.is_false(clock._clocked_headline_searched)
      assert.is_false(search_called)

      -- Call _ensure_clocked_headline_searched directly
      clock:_ensure_clocked_headline_searched()

      -- Should be true now - searched because files are loaded
      assert.is_true(clock._clocked_headline_searched)
      assert.is_true(search_called)
    end)
  end)
end)

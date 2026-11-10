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

  after_each(function()
    for _, group in ipairs({
      'OrgApiHandleIdRemovedHook',
      'test_read_autocmd_inserts_headline',
      'test_read_autocmd_removes_headline',
      'test_enter_autocmd_edits',
      'OrgApiHandleCookieInsertHook',
      'OrgApiHandleTwinSwapHook',
      'OrgApiHandleTwinRemoveHook',
      'OrgApiHandleSimilarSwapHook',
      'test_read_autocmd_wipes_buffer',
    }) do
      pcall(vim.api.nvim_del_augroup_by_name, group)
    end
  end)

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

  it('loads a file by a list of names that cannot be read again with its loaded content', function()
    local files = helpers.create_agenda_files({
      { filename = 'first.org', content = { '* TODO First' } },
      { filename = 'second.org', content = { '* TODO Second' } },
    })
    vim.wait(10)
    vim.fn.writefile({ '* TODO Changed' }, files['first.org'])
    vim.uv.fs_chmod(files['first.org'], 0)

    local ok, loaded = pcall(api.load, { files['first.org'], files['second.org'] })
    vim.uv.fs_chmod(files['first.org'], 420)

    assert.is.True(ok, loaded)
    assert.are.same({ 'First', 'Second' }, {
      loaded[1].headlines[1].title,
      loaded[2].headlines[1].title,
    })
  end)

  it('loads all files with the loaded content of a file that cannot be read again', function()
    local files = helpers.create_agenda_files({
      { filename = 'first.org', content = { '* TODO First' } },
      { filename = 'second.org', content = { '* TODO Second' } },
    })
    vim.wait(10)
    vim.fn.writefile({ '* TODO Changed' }, files['first.org'])
    vim.uv.fs_chmod(files['first.org'], 0)

    local ok, loaded = pcall(api.load)
    vim.uv.fs_chmod(files['first.org'], 420)

    assert.is.True(ok, loaded)
    local titles = vim.tbl_map(function(file)
      return file.headlines[1].title
    end, loaded)
    table.sort(titles)
    assert.are.same({ 'First', 'Second' }, titles)
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

  it('returns nil on reload after its headline was deleted', function()
    helpers.create_file({
      '* TODO First',
      '* TODO Second',
    })
    local headline = cur_file().headlines[2]

    vim.api.nvim_buf_set_lines(0, 1, 2, false, {})

    assert.is.Nil(headline:reload())
  end)

  it('returns nil on reload after the headline with its id was deleted', function()
    helpers.create_file({
      '* TODO First',
      '* TODO Second',
      '  :PROPERTIES:',
      '  :ID: reload-id',
      '  :END:',
    })
    local headline = cur_file().headlines[2]

    vim.api.nvim_buf_set_lines(0, 1, 5, false, {})

    assert.is.Nil(headline:reload())
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

  it('keeps the handle usable for further mutations after lines were inserted above', function()
    helpers.create_file({
      '* TODO First',
      '* TODO Second',
    })
    local headline = cur_file().headlines[2]

    vim.api.nvim_buf_set_lines(0, 0, 0, false, { '* TODO Inserted' })

    headline:set_tags({ 'one' }):wait()
    headline:set_priority('A'):wait()
    headline:set_tags({ 'two' }):wait()
    assert.are.same('A', headline.priority)
    assert.is.Not.Nil(vim.api.nvim_buf_get_lines(0, 0, -1, false)[3]:match('^%* TODO %[#A%] Second%s+:two:$'))
  end)

  it('finds its headline by id after a write hook moved it', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleMoveHook', { clear = true })
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '#+TITLE: Hooked' then
          vim.api.nvim_buf_set_lines(0, 0, 0, false, { '#+TITLE: Hooked' })
        end
      end,
    })
    helpers.create_file({
      '* TODO First',
      ':PROPERTIES:',
      ':ID: moved-by-hook',
      ':END:',
    })
    local headline = cur_file().headlines[1]

    local ok, err = pcall(function()
      headline:set_priority('A'):wait()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert(ok, err)
    assert.are.same('A', headline.priority)
    assert.are.same('* TODO [#A] First', vim.api.nvim_buf_get_lines(0, 0, -1, false)[2])
  end)

  it('keeps sibling handles on their headlines after a write hook reordered them', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleReorderHook', { clear = true })
    local reordered = false
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if reordered then
          return
        end
        reordered = true
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { lines[5], lines[1], lines[2], lines[3], lines[4] })
      end,
    })
    helpers.create_file({
      '* TODO A',
      ':PROPERTIES:',
      ':ID: reordered-by-hook',
      ':END:',
      '* TODO B',
    })
    local file = cur_file()
    local a, b = file.headlines[1], file.headlines[2]

    local ok, err = pcall(function()
      a:set_priority('A'):wait()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert(ok, err)
    assert.are.same({ 'A', 'A' }, { a.title, a.priority })
    b:set_tags({ 'x' }):wait()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.is.Not.Nil(lines[1]:match('^%* TODO B%s+:x:$'))
    assert.are.same('* TODO [#A] A', lines[2])
  end)

  it('keeps sibling handles on their ids after a write hook swapped identical siblings', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleSwapSameHook', { clear = true })
    local swapped = false
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if swapped then
          return
        end
        swapped = true
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        vim.api.nvim_buf_set_lines(
          0,
          1,
          -1,
          false,
          { lines[6], lines[7], lines[8], lines[9], lines[2], lines[3], lines[4], lines[5] }
        )
      end,
    })
    helpers.create_file({
      '* TODO Acting',
      '* TODO Same',
      ':PROPERTIES:',
      ':ID: first-same',
      ':END:',
      '* TODO Same',
      ':PROPERTIES:',
      ':ID: second-same',
      ':END:',
    })
    local file = cur_file()
    local acting, first, second = file.headlines[1], file.headlines[2], file.headlines[3]

    local ok, err = pcall(function()
      acting:set_priority('A'):wait()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert(ok, err)
    assert.are.same({ 'first-same', 'second-same' }, { first.properties.id, second.properties.id })
    first:set_tags({ 'x' }):wait()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({ '* TODO Same', ':ID: second-same' }, { lines[2], lines[4] })
    assert.is.Not.Nil(lines[6]:match('^%* TODO Same%s+:x:$'))
    assert.are.same(':ID: first-same', lines[8])
  end)

  it('raises an error when a write hook replaced the buffer to swap a handle without an id with its sibling', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleSwapHook', { clear = true })
    local swapped = false
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if swapped then
          return
        end
        swapped = true
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { lines[2], lines[1] })
      end,
    })
    helpers.create_file({
      '* TODO A',
      '* TODO B',
    })
    local headline = cur_file().headlines[1]

    local ok, err = pcall(function()
      headline:set_priority('A'):wait()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert.is.False(ok)
    assert.is.Not.Nil(tostring(err):match('no longer on line 1'))
    assert.are.same({ '* TODO B', '* TODO [#A] A' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('keeps a handle without an id on its headline after a write hook inserted a line above', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleInsertHook', { clear = true })
    local inserted = false
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if inserted then
          return
        end
        inserted = true
        vim.api.nvim_buf_set_lines(0, 0, 0, false, { '#+TITLE: Hooked' })
      end,
    })
    helpers.create_file({
      '* TODO First',
      '* TODO Second',
    })
    local file = cur_file()
    local first, second = file.headlines[1], file.headlines[2]

    local ok, err = pcall(function()
      first:set_priority('A'):wait()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert(ok, err)
    assert.are.same({ 'First', 2 }, { first.title, first.position.start_line })
    first:set_tags({ 'x' }):wait()
    second:set_tags({ 'y' }):wait()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same('#+TITLE: Hooked', lines[1])
    assert.is.Not.Nil(lines[2]:match('^%* TODO %[#A%] First%s+:x:$'))
    assert.is.Not.Nil(lines[3]:match('^%* TODO Second%s+:y:$'))
  end)

  it('raises an error when a write hook replaced the line of a headline without an id', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleLineHook', { clear = true })
    local changed = false
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if changed then
          return
        end
        changed = true
        local line = vim.api.nvim_buf_get_lines(0, 1, 2, false)[1]
        vim.api.nvim_buf_set_lines(0, 1, 2, false, { line .. ' :hooked:' })
      end,
    })
    helpers.create_file({
      '* TODO First',
      '* TODO Second',
    })
    local file = cur_file()
    local first, second = file.headlines[1], file.headlines[2]

    local ok, err = pcall(function()
      second:set_priority('A'):wait()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert.is.False(ok)
    assert.is.Not.Nil(tostring(err):match('no longer on line 2'))
    assert.are.same({ '* TODO First', '* TODO [#A] Second :hooked:' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('finds its headline by the new id when get_link creates it and a write hook moves the headline', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleIdMoveHook', { clear = true })
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '#+TITLE: Hooked' then
          vim.api.nvim_buf_set_lines(0, 0, 0, false, { '#+TITLE: Hooked' })
        end
      end,
    })
    helpers.create_file({ '* TODO Same', '* TODO Same' })
    local headline = cur_file().headlines[2]

    local ok, link = pcall(function()
      local result = nil
      helpers.with_var(config.opts, 'org_id_link_to_org_use_id', true, function()
        result = headline:get_link()
      end)
      return result
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert(ok, link)
    local id = link:match('^id:(.+)::%*Same$')
    assert.is.Not.Nil(id)
    assert.are.same(id, headline.properties.id)
    assert.are.same(3, headline.position.start_line)
  end)

  it('finds a nested handle without an id after a write hook inserted a line above', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleNestedHook', { clear = true })
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '#+TITLE: Hooked' then
          vim.api.nvim_buf_set_lines(0, 0, 0, false, { '#+TITLE: Hooked' })
        end
      end,
    })
    helpers.create_file({ '* Parent', '** TODO Child' })
    local headline = cur_file().headlines[2]

    local ok, err = pcall(function()
      headline:set_priority('A'):wait()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert(ok, err)
    assert.are.same(3, headline.position.start_line)
  end)

  it('follows its headline when a write hook moves another identical headline onto the old line', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleTwinShiftHook', { clear = true })
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '#+TITLE: Hooked' then
          vim.api.nvim_buf_set_lines(0, 0, 0, false, { '#+TITLE: Hooked' })
        end
      end,
    })
    helpers.create_file({ '* TODO [#A] Same', '* TODO Same', 'second body' })
    local headline = cur_file().headlines[2]

    local ok, err = pcall(function()
      headline:set_priority('A'):wait()
      headline:set_tags({ 'x' }):wait()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert(ok, err)
    assert.are.same(3, headline.position.start_line)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same('* TODO [#A] Same', lines[2])
    assert.is.Not.Nil(lines[3]:match('^%* TODO %[#A%] Same%s+:x:$'))
  end)

  it('raises an error when a write hook removes its headline and an identical one stays', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleTwinGoneHook', { clear = true })
    local removed = false
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if not removed then
          removed = true
          vim.api.nvim_buf_set_lines(0, 1, 3, false, { 'plain text', 'more text' })
        end
      end,
    })
    helpers.create_file({ '* Pad', '* TODO Same', 'body one', '* TODO Same', 'body two' })
    local headline = cur_file().headlines[2]

    local ok, err = pcall(function()
      headline:set_deadline('2026-01-01'):wait()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert.is.False(ok)
    assert.is.Not.Nil(tostring(err):match('no longer on line 2'))
  end)

  it('raises an error when a write hook swaps its headline with one the action made identical', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleTwinSwapHook', { clear = true })
    local swapped = false
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if swapped then
          return
        end
        swapped = true
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { lines[3], lines[4], lines[1], lines[2] })
      end,
    })
    local file = helpers.create_file({ '* TODO [#A] Same', 'first body', '* TODO Same', 'second body' })
    local headline = cur_file().headlines[2]

    local ok, err = pcall(function()
      headline:set_priority('A'):wait()
    end)

    assert.is.False(ok)
    assert.is.Not.Nil(tostring(err):match('no longer on line 3'))
    assert.are.same(
      { '* TODO [#A] Same', 'second body', '* TODO [#A] Same', 'first body' },
      vim.fn.readfile(file.filename)
    )
  end)

  it('raises an error when a write hook removes its headline after the action made it identical', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleTwinRemoveHook', { clear = true })
    local removed = false
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if not removed then
          removed = true
          vim.api.nvim_buf_set_lines(0, 2, 4, false, {})
        end
      end,
    })
    local file = helpers.create_file({ '* TODO [#A] Same', 'first body', '* TODO Same', 'second body' })
    local headline = cur_file().headlines[2]

    local ok, err = pcall(function()
      headline:set_priority('A'):wait()
    end)

    assert.is.False(ok)
    assert.is.Not.Nil(tostring(err):match('no longer on line 3'))
    assert.are.same({ '* TODO [#A] Same', 'first body' }, vim.fn.readfile(file.filename))
  end)

  it('raises an error when a write hook replaced the buffer to swap its headline with a similar one', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleSimilarSwapHook', { clear = true })
    local swapped = false
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if swapped then
          return
        end
        swapped = true
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        vim.api.nvim_buf_set_lines(0, 0, -1, false, { lines[3], lines[4], lines[1], lines[2] })
      end,
    })
    local file = helpers.create_file({ '* TODO [#A] Same', 'first body', '* TODO Same', 'second body' })
    local headline = cur_file().headlines[2]

    local ok, err = pcall(function()
      headline:set_priority('B'):wait()
    end)

    assert.is.False(ok)
    assert.is.Not.Nil(tostring(err):match('no longer on line 3'))
    assert.are.same(
      { '* TODO [#B] Same', 'second body', '* TODO [#A] Same', 'first body' },
      vim.fn.readfile(file.filename)
    )
  end)

  it('raises an error when a write hook removes the headline with its id', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleIdGoneHook', { clear = true })
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == ':ID: first-id' then
          vim.api.nvim_buf_set_lines(0, 0, 5, false, {})
        end
      end,
    })
    helpers.create_file({
      '* TODO Same',
      ':PROPERTIES:',
      ':ID: first-id',
      ':END:',
      '* TODO Same',
      ':PROPERTIES:',
      ':ID: second-id',
      ':END:',
    })
    local headline = cur_file().headlines[1]

    local ok, err = pcall(function()
      headline:set_property('FOO', 'bar'):wait()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert.is.False(ok)
    assert.is.Not.Nil(tostring(err):match('no longer on line 1'))
    assert.are.same('first-id', headline.properties.id)
  end)

  it('raises an error when a write hook replaces the headline with its id', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleIdReplacedHook', { clear = true })
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if vim.api.nvim_buf_get_lines(0, 2, 3, false)[1] == ':ID: mine' then
          vim.api.nvim_buf_set_lines(0, 0, 3, false, { '* TODO Replacement', ':PROPERTIES:', ':ID: other' })
        end
      end,
    })
    helpers.create_file({ '* TODO Mine', ':PROPERTIES:', ':ID: mine', ':END:' })
    local headline = cur_file().headlines[1]

    local ok, err = pcall(function()
      headline:set_priority('A'):wait()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert.is.False(ok)
    assert.is.Not.Nil(tostring(err):match('no longer on line 1'))
  end)

  describe('with a write hook that edits the buffer once', function()
    local group = nil

    ---@param hook fun()
    local function on_first_write(hook)
      group = vim.api.nvim_create_augroup('OrgApiHandleMarkHook', { clear = true })
      vim.api.nvim_create_autocmd('BufWritePre', { group = group, once = true, callback = hook })
    end

    ---@return { marks: table[], autocmds: table[] }
    local function leftovers()
      local namespace = vim.api.nvim_get_namespaces()['orgmode.api.headline']
      return {
        marks = namespace and vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, {}) or {},
        autocmds = vim.api.nvim_get_autocmds({ event = 'BufWritePost', buffer = 0 }),
      }
    end

    after_each(function()
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end)

    it('follows a handle without an id when the hook inserts lines above it', function()
      helpers.create_file({ '* TODO Same', '* TODO Same' })
      local headline = cur_file().headlines[2]
      local before = leftovers()
      on_first_write(function()
        vim.api.nvim_buf_set_lines(0, 0, 0, false, { '#+TITLE: Hooked', '' })
      end)

      headline:set_priority('A'):wait()

      assert.are.same({ 4, 'A' }, { headline.position.start_line, headline.priority })
      assert.are.same('* TODO [#A] Same', vim.api.nvim_buf_get_lines(0, 3, 4, false)[1])
      assert.are.same(before, leftovers())
    end)

    it('follows a handle without an id when the hook moves the subtree below it above it', function()
      local file = helpers.create_file({ '* TODO A', 'a body', '* TODO B', 'b body' })
      local headline = cur_file().headlines[1]
      on_first_write(function()
        local moved = vim.api.nvim_buf_get_lines(0, 2, 4, false)
        vim.api.nvim_buf_set_lines(0, 2, 4, false, {})
        vim.api.nvim_buf_set_lines(0, 0, 0, false, moved)
      end)

      headline:set_priority('A'):wait()

      assert.are.same({ 3, 'A', 'A' }, { headline.position.start_line, headline.title, headline.priority })
      assert.are.same({ '* TODO B', 'b body', '* TODO [#A] A', 'a body' }, vim.fn.readfile(file.filename))
    end)

    -- Deleting lines deletes the marks on them, so the headline cannot be followed to where they are put back
    it('raises an error when the hook deletes the subtree of a handle without an id and puts it back', function()
      local file = helpers.create_file({ '* TODO A', 'a body', '* TODO B', 'b body' })
      local headline = cur_file().headlines[2]
      on_first_write(function()
        local moved = vim.api.nvim_buf_get_lines(0, 2, 4, false)
        vim.api.nvim_buf_set_lines(0, 2, 4, false, {})
        vim.api.nvim_buf_set_lines(0, 0, 0, false, moved)
      end)

      local ok, err = pcall(function()
        headline:set_priority('A'):wait()
      end)

      assert.is.False(ok)
      assert.is.Not.Nil(tostring(err):match('no longer on line 3'))
      assert.are.same({ '* TODO [#A] B', 'b body', '* TODO A', 'a body' }, vim.fn.readfile(file.filename))
    end)

    it('raises an error when the hook replaces the whole buffer and adds a line', function()
      local file = helpers.create_file({ '* TODO A', '* TODO B' })
      local headline = cur_file().headlines[2]
      on_first_write(function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.api.nvim_buf_get_lines(0, 0, -1, false))
        vim.api.nvim_buf_set_lines(0, -1, -1, false, { '* TODO C' })
      end)

      local ok, err = pcall(function()
        headline:set_priority('A'):wait()
      end)

      assert.is.False(ok)
      assert.is.Not.Nil(tostring(err):match('no longer on line 2'))
      assert.are.same({ '* TODO A', '* TODO [#A] B', '* TODO C' }, vim.fn.readfile(file.filename))
    end)

    it('raises an error when the hook deletes the line of a handle without an id', function()
      local file = helpers.create_file({ '* TODO A', '* TODO B', '* TODO C' })
      local headline = cur_file().headlines[2]
      on_first_write(function()
        vim.api.nvim_buf_set_lines(0, 1, 2, false, {})
      end)

      local ok, err = pcall(function()
        headline:set_priority('A'):wait()
      end)

      assert.is.False(ok)
      assert.is.Not.Nil(tostring(err):match('no longer on line 2'))
      assert.are.same({ '* TODO A', '* TODO C' }, vim.fn.readfile(file.filename))
    end)

    it('leaves no mark or autocmd behind when the buffer had unsaved edits and the save is skipped', function()
      helpers.create_file({ '* TODO A', '* TODO B' })
      local headline = cur_file().headlines[2]
      local before = leftovers()
      vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'unsaved' })

      headline:set_priority('A'):wait()

      assert.is.True(vim.bo.modified)
      assert.are.same('A', headline.priority)
      assert.are.same(before, leftovers())
    end)

    it('leaves no mark or autocmd behind when the action fails', function()
      helpers.create_file({ '* TODO A', '* TODO B' })
      local headline = cur_file().headlines[2]
      local before = leftovers()

      local ok = pcall(function()
        headline:set_deadline('garbage'):wait()
      end)

      assert.is.False(ok)
      assert.are.same(before, leftovers())
    end)
  end)

  it('keeps an out of date handle when the mutation makes it identical to another headline', function()
    helpers.create_file({ '* TODO [#A] Same', '* TODO Same' })
    local headline = cur_file().headlines[2]
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { '* TODO Added' })

    headline:set_priority('A'):wait()

    assert.are.same('A', headline.priority)
    assert.are.same(2, headline.position.start_line)
  end)

  it('keeps an out of date handle when set_property removes its id', function()
    helpers.create_file({ '* TODO Same', ':PROPERTIES:', ':ID: removed-id', ':END:', '* TODO Same' })
    local headline = cur_file().headlines[1]
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { '* TODO Added' })

    headline:set_property('ID', nil):wait()

    assert.is.Nil(headline.properties.id)
    assert.are.same(1, headline.position.start_line)
  end)

  it('finds its headline after set_property removes its id and a write hook inserted a line above', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleIdRemovedHook', { clear = true })
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      callback = function()
        if vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= '* TODO Inserted' then
          vim.api.nvim_buf_set_lines(0, 0, 0, false, { '* TODO Inserted' })
        end
      end,
    })
    helpers.create_file({ '* TODO Mine', ':PROPERTIES:', ':ID: removed-id', ':END:' })
    local headline = cur_file().headlines[1]

    local ok, err = pcall(function()
      headline:set_property('ID', nil):wait()
    end)

    assert.is.True(ok, err)
    assert.is.Nil(headline.properties.id)
    assert.are.same('Mine', headline.title)
    assert.are.same(2, headline.position.start_line)
  end)

  it('keeps the handle when set_property gives it an id another headline has', function()
    helpers.create_file({ '* TODO A', '* TODO B', ':PROPERTIES:', ':ID: taken-id', ':END:' })
    local headline = cur_file().headlines[1]

    headline:set_property('ID', 'taken-id'):wait()

    assert.are.same('taken-id', headline.properties.id)
    assert.are.same('A', headline.title)
  end)

  it('refreshes an out of date handle when another buffer is current after the action', function()
    helpers.create_file({ '* TODO First', '* TODO Second' })
    local headline = cur_file().headlines[1]
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { '* TODO Added' })
    vim.cmd.write()

    local pending = headline:set_priority('A')
    vim.cmd.enew()
    local ok, err = pcall(function()
      pending:wait()
    end)

    assert(ok, err)
    headline:set_tags({ 'x' }):wait()
    assert.are.same('A', headline.priority)
    assert.are.same({ 'x' }, headline.tags)
  end)

  it('applies a mutator to every identical headline in a loop over one load', function()
    helpers.create_file({
      '* TODO Same',
      '* TODO Same',
    })

    for _, headline in ipairs(cur_file().headlines) do
      headline:set_priority('A'):wait()
    end

    assert.are.same({ '* TODO [#A] Same', '* TODO [#A] Same' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('keeps sibling handles valid after a mutation through another handle of the same load', function()
    helpers.create_file({
      '* TODO A',
      '* TODO Same',
      '* TODO Same',
    })
    local file = cur_file()

    file.headlines[1]:set_tags({ 'x' }):wait()
    file.headlines[2]:set_tags({ 'y' }):wait()

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.is.Not.Nil(lines[1]:match('^%* TODO A%s+:x:$'))
    assert.is.Not.Nil(lines[2]:match('^%* TODO Same%s+:y:$'))
    assert.are.same('* TODO Same', lines[3])
  end)

  it('updates the handle when its headline is mutated through a child handle parent', function()
    helpers.create_file({
      '* TODO Parent',
      '** TODO Child',
    })
    local parent = cur_file().headlines[1]

    parent:set_tags({ 'one' }):wait()
    parent.headlines[1].parent:set_priority('A'):wait()

    assert.are.same('A', parent.priority)
    assert.are.equal(parent, parent.headlines[1].parent)
  end)

  it('keeps the handle valid when a write hook changes the file on save', function()
    local group = vim.api.nvim_create_augroup('OrgApiHandleWriteHook', { clear = true })
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = group,
      command = [[%s/\s\+$//e]],
    })
    helpers.create_file({
      '* TODO Same',
      'body ',
      '* TODO Same',
    })
    local headline = cur_file().headlines[2]

    local ok, err = pcall(function()
      headline:set_deadline('2026-01-01'):wait()
      headline:set_priority('A'):wait()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    assert(ok, err)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({ '* TODO Same', 'body' }, { lines[1], lines[2] })
    assert.are.same('* TODO [#A] Same', lines[3])
  end)

  it('saves a refile under a headline in the current file', function()
    local file = helpers.create_file({ '* TODO Alpha', '* Target', '* TODO Gamma' })
    local headlines = cur_file().headlines

    api.refile({ source = headlines[1], destination = headlines[2] }):wait()

    assert.are.same({ '* Target', '** TODO Alpha', '* TODO Gamma' }, vim.fn.readfile(file.filename))
  end)

  it('refiles its own headline after a headline was inserted above', function()
    local destination = helpers.create_agenda_file({ '* Destination' })
    helpers.create_file({
      '* TODO First',
      '* TODO Second',
    })
    local headline = cur_file().headlines[2]

    vim.api.nvim_buf_set_lines(0, 0, 0, false, { '* TODO Inserted' })
    api.refile({ source = headline, destination = api.load(destination.filename) }):wait()

    assert.are.same({ '* TODO Inserted', '* TODO First' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('refiles under its destination headline after a headline was inserted above it', function()
    local destination = helpers.create_agenda_file({
      '* Destination A',
      '* Destination B',
    })
    local destination_bufnr = vim.fn.bufnr(destination.filename)
    local destination_headline = api.load(destination.filename).headlines[2]
    helpers.create_file({ '* TODO Source' })
    local headline = cur_file().headlines[1]

    vim.api.nvim_buf_set_lines(destination_bufnr, 0, 0, false, { '* Inserted' })
    api.refile({ source = headline, destination = destination_headline }):wait()

    assert.are.same(
      { '* Inserted', '* Destination A', '* Destination B', '** TODO Source' },
      vim.api.nvim_buf_get_lines(destination_bufnr, 0, -1, false)
    )
  end)

  it('writes a file that is not loaded once when get_link creates the link id', function()
    local files = helpers.create_agenda_files({
      { filename = 'target.org', content = { '* TODO Target' } },
    })
    local headline = api.load(files['target.org']).headlines[1]
    local writes = 0
    local group = vim.api.nvim_create_augroup('test_get_link_writes', { clear = true })
    vim.api.nvim_create_autocmd('BufWritePost', {
      group = group,
      -- Orgmode writes the file under its resolved path, which differs where the temp dir is a symlink
      pattern = vim.fn.resolve(files['target.org']),
      callback = function()
        writes = writes + 1
      end,
    })

    local link = nil
    helpers.with_var(config.opts, 'org_id_link_to_org_use_id', true, function()
      link = headline:get_link()
    end)
    vim.api.nvim_del_augroup_by_id(group)

    local id = link:match('^id:(.+)::%*Target$')
    assert.is.Not.Nil(id)
    assert.are.same(id, api.load(files['target.org']).headlines[1]:get_property('id'))
    assert.are.same(1, writes)
  end)

  it('creates the link id on its own headline after a headline was inserted above', function()
    helpers.create_file({
      '* TODO First',
      '* TODO Second',
    })
    local headline = cur_file().headlines[2]

    vim.api.nvim_buf_set_lines(0, 0, 0, false, { '* TODO Inserted' })
    local link = nil
    helpers.with_var(config.opts, 'org_id_link_to_org_use_id', true, function()
      link = headline:get_link()
    end)

    local id = link:match('^id:(.+)::%*Second$')
    assert.is.Not.Nil(id)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({ '* TODO Inserted', '* TODO First', '* TODO Second' }, { lines[1], lines[2], lines[3] })
    assert.is.Not.Nil(lines[5]:match(':ID: ' .. vim.pesc(id) .. '$'))
  end)

  it('returns the same link when get_link creates the id of one of two identical headlines', function()
    helpers.create_file({
      '* TODO Same',
      '* TODO Same',
    })
    local headline = cur_file().headlines[2]

    local first, second
    helpers.with_var(config.opts, 'org_id_link_to_org_use_id', true, function()
      first = headline:get_link()
      second = headline:get_link()
    end)

    assert.is.Not.Nil(first:match('^id:.+::%*Same$'))
    assert.are.same(first, second)
  end)

  it('reuses the id another handle created when get_link creates the link id', function()
    local file = helpers.create_agenda_file({ '* TODO First' })
    local headline = api.load(file.filename).headlines[1]
    local id = api.load(file.filename).headlines[1]:id_get_or_create()

    local link = nil
    helpers.with_var(config.opts, 'org_id_link_to_org_use_id', true, function()
      link = headline:get_link()
    end)

    assert.are.same('id:' .. id .. '::*First', link)
    assert.are.same(id, api.load(file.filename).headlines[1]:get_property('id'))
  end)

  it('reuses the id another handle created when id_get_or_create is called', function()
    local file = helpers.create_agenda_file({ '* TODO First' })
    local headline = api.load(file.filename).headlines[1]
    local id = api.load(file.filename).headlines[1]:id_get_or_create()

    assert.are.same(id, headline:id_get_or_create())
    assert.are.same(id, api.load(file.filename).headlines[1]:get_property('id'))
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

    local promise = headline:set_tags({ 'x' })
    assert.has.error(function()
      promise:wait()
    end)
    assert.are.same({ '* TODO Inserted', '* TODO Same', '* TODO Same' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('tells identical headlines under different parents apart after an edit', function()
    helpers.create_file({ '* A', '** Notes', '* B', '** Notes', 'body' })
    local headline = cur_file().headlines[4]

    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'more body' })
    headline:set_tags({ 'x' }):wait()

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.are.same({ '* A', '** Notes', '* B' }, { lines[1], lines[2], lines[3] })
    assert.is.Not.Nil(lines[4]:match('^%*%* Notes%s+:x:$'))
  end)

  it('raises an error instead of guessing between identical headlines under the same parent after an edit', function()
    helpers.create_file({ '* A', '** Notes', '** Notes' })
    local headline = cur_file().headlines[3]

    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'body' })

    local promise = headline:set_tags({ 'x' })
    assert.has.error(function()
      promise:wait()
    end)
    assert.are.same({ '* A', '** Notes', '** Notes', 'body' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('raises an error when a slash in a title gives two headlines the same outline path', function()
    helpers.create_file({ '* A/B', '*** C', '* A', '** B', '*** C' })
    local headline = cur_file().headlines[5]

    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'body' })

    local promise = headline:set_tags({ 'x' })
    assert.has.error(function()
      promise:wait()
    end)
    assert.are.same({ '* A/B', '*** C', '* A', '** B', '*** C', 'body' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('passes the error to a catch handler when the handle no longer finds its headline', function()
    helpers.create_file({
      '* TODO Same',
      '* TODO Same',
    })
    local headline = cur_file().headlines[2]
    vim.api.nvim_buf_set_lines(0, 0, 0, false, { '* TODO Inserted' })

    local caught = nil
    local ok = pcall(function()
      headline
        :set_tags({ 'x' })
        :catch(function(err)
          caught = err
        end)
        :wait()
    end)

    assert.is.True(ok)
    assert.is.Not.Nil(caught:match('not found'))
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

    local promise = headline:set_tags({ 'x' })
    assert.has.error(function()
      promise:wait()
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

    local promise = headline:set_tags({ 'x' })
    assert.has.error(function()
      promise:wait()
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

  it('acts on its own headline after the file of a hidden buffer without edits changed on disk', function()
    local target = helpers.create_agenda_file({ '* TODO A', '* TODO B' })
    helpers.create_file({ '* TODO Other' })
    api.load(target.filename).headlines[1]:set_priority('A'):wait()
    vim.wait(10)
    vim.fn.writefile({ '* TODO Ext', '* TODO [#A] A', '* TODO B' }, target.filename)

    local headline = vim.tbl_filter(function(item)
      return item.title == 'B'
    end, api.load(target.filename).headlines)[1]
    headline:set_tags({ 'x' }):wait()

    local lines = vim.fn.readfile(target.filename)
    assert.are.same({ '* TODO Ext', '* TODO [#A] A' }, { lines[1], lines[2] })
    assert.is.Not.Nil(lines[3]:match('^%* TODO B%s+:x:$'))
  end)

  it('acts on its own headline after the file of a hidden buffer changed on disk without autoread', function()
    local target = helpers.create_agenda_file({ '* TODO A', '* TODO B' })
    helpers.create_file({ '* TODO Other' })
    api.load(target.filename).headlines[1]:set_priority('A'):wait()
    vim.wait(10)
    vim.fn.writefile({ '* TODO Ext', '* TODO [#A] A', '* TODO B' }, target.filename)

    helpers.with_var(vim.o, 'autoread', false, function()
      local headline = vim.tbl_filter(function(item)
        return item.title == 'B'
      end, api.load(target.filename).headlines)[1]
      headline:set_tags({ 'x' }):wait()
    end)

    local lines = vim.fn.readfile(target.filename)
    assert.are.same({ '* TODO Ext', '* TODO [#A] A' }, { lines[1], lines[2] })
    assert.is.Not.Nil(lines[3]:match('^%* TODO B%s+:x:$'))
  end)

  it('loads a file when an autocmd loads it again while its buffer is read from disk', function()
    local file = helpers.create_agenda_file({ '* TODO Old' })
    local group = vim.api.nvim_create_augroup('test_load_while_buffer_is_read', { clear = true })
    vim.api.nvim_create_autocmd('BufReadPost', {
      group = group,
      pattern = '*.org',
      callback = function()
        api.load(file.filename)
      end,
    })
    vim.wait(10)
    vim.fn.writefile({ '* TODO New' }, file.filename)

    local ok, loaded = pcall(api.load, file.filename)
    vim.api.nvim_del_augroup_by_id(group)

    assert.is.True(ok, loaded)
    assert.are.same('New', loaded.headlines[1].title)
  end)

  it('reads the file from disk when an autocmd wipes its buffer while it is read from disk', function()
    local file = helpers.create_agenda_file({ '* TODO Old' })
    local bufnr = vim.fn.bufnr(file.filename)
    helpers.create_file({ '* TODO Other' })
    local group = vim.api.nvim_create_augroup('test_read_autocmd_wipes_buffer', { clear = true })
    vim.api.nvim_create_autocmd('BufReadPost', {
      group = group,
      buffer = bufnr,
      callback = function()
        vim.cmd('bwipeout! ' .. bufnr)
      end,
    })
    vim.wait(10)
    vim.fn.writefile({ '* TODO New' }, file.filename)

    local ok, reloaded = pcall(file.reload_sync, file)

    assert.is.True(ok, reloaded)
    assert.are.same(-1, vim.fn.bufnr(file.filename))
    assert.are.same({ '* TODO New' }, reloaded.lines)
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

  it('raises an error when the handle of one of two identical headlines outlives its headline', function()
    helpers.create_file({
      '* TODO Same',
      '* TODO Same',
    })
    local headline = cur_file().headlines[2]

    vim.api.nvim_buf_set_lines(0, 1, 2, false, {})

    local promise = headline:set_tags({ 'x' })
    assert.has.error(function()
      promise:wait()
    end)
    assert.are.same({ '* TODO Same' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('acts on its own headline after the file was reordered and opened in a new buffer', function()
    -- The tick a buffer gets when the file is opened again
    local probe = helpers.create_file({ '* TODO Probe' })
    local probe_bufnr = vim.api.nvim_get_current_buf()
    vim.cmd('enew')
    vim.cmd('bwipeout ' .. probe_bufnr)
    vim.cmd('edit ' .. vim.fn.fnameescape(probe.filename))
    local reopen_tick = vim.api.nvim_buf_get_changedtick(0)

    local file = helpers.create_file({ '* TODO First', '* TODO Second' })
    local old_bufnr = vim.api.nvim_get_current_buf()
    while vim.api.nvim_buf_get_changedtick(old_bufnr) < reopen_tick do
      vim.api.nvim_buf_set_lines(old_bufnr, 0, 1, false, { '* TODO First' })
    end
    local old_tick = vim.api.nvim_buf_get_changedtick(old_bufnr)
    local headline = cur_file().headlines[2]

    vim.cmd('enew')
    vim.cmd('bwipeout! ' .. old_bufnr)
    vim.wait(10)
    vim.fn.writefile({ '* TODO Second', '* TODO First' }, file.filename)
    vim.cmd('edit ' .. vim.fn.fnameescape(file.filename))
    assert.are.same(old_tick, vim.api.nvim_buf_get_changedtick(0))

    headline:set_tags({ 'x' }):wait()

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    assert.is.Not.Nil(lines[1]:match('^%* TODO Second%s+:x:$'))
    assert.are.same('* TODO First', lines[2])
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

  it('keeps the swapfile of a hidden buffer with unsaved edits on an api mutation', function()
    local target = helpers.create_agenda_file({ '* TODO Target' })
    local target_bufnr = vim.fn.bufnr(target.filename)
    vim.bo[target_bufnr].swapfile = true
    vim.api.nvim_buf_set_lines(target_bufnr, -1, -1, false, { 'unsaved user edit' })
    helpers.create_file({ '* TODO Other buffer' })

    api.load(target.filename).headlines[1]:set_tags({ 'api' }):wait()

    assert.is.True(vim.bo[target_bufnr].modified)
    assert.is.True(vim.bo[target_bufnr].swapfile)
  end)

  it('leaves an unloaded buffer unloaded after an api mutation', function()
    local target = helpers.create_agenda_file({ '* TODO Target' })
    local target_bufnr = vim.fn.bufnr(target.filename)
    helpers.create_file({ '* TODO Other buffer' })
    vim.cmd('bunload ' .. target_bufnr)

    api.load(target.filename).headlines[1]:set_tags({ 'x' }):wait()

    assert.is.False(vim.api.nvim_buf_is_loaded(target_bufnr))
    assert.is.Not.Nil(vim.fn.readfile(target.filename)[1]:match('^%* TODO Target%s+:x:$'))
  end)

  it('rejects an api mutation of an unloaded buffer whose file cannot be written', function()
    local target = helpers.create_agenda_file({ '* TODO Target' })
    local target_bufnr = vim.fn.bufnr(target.filename)
    helpers.create_file({ '* TODO Other buffer' })
    vim.cmd('bunload ' .. target_bufnr)
    local headline = api.load(target.filename).headlines[1]
    vim.uv.fs_chmod(target.filename, 292)

    local ok, err = pcall(function()
      headline:set_tags({ 'x' }):wait()
    end)
    vim.uv.fs_chmod(target.filename, 420)

    assert.is.False(ok)
    assert.is.Not.Nil(tostring(err):match('Could not write'))
    assert.are.same({ '* TODO Target' }, vim.fn.readfile(target.filename))
    assert.is.False(vim.api.nvim_buf_is_loaded(target_bufnr))
  end)

  for _, case in ipairs({
    { name = 'with', lines = { '* TODO Target', ':PROPERTIES:', ':ID: target-id', ':END:' } },
    { name = 'without', lines = { '* TODO Target' } },
  }) do
    it('rejects an api mutation of a headline ' .. case.name .. ' id in a file that cannot be written', function()
      local target = helpers.create_agenda_file(case.lines)
      helpers.create_file({ '* TODO Other buffer' })
      vim.cmd('bwipeout! ' .. vim.fn.bufnr(target.filename))
      local headline = api.load(target.filename).headlines[1]
      vim.uv.fs_chmod(target.filename, 292)

      local ok, err = pcall(function()
        headline:set_tags({ 'x' }):wait()
      end)
      vim.uv.fs_chmod(target.filename, 420)

      assert.is.False(ok)
      assert.is.Not.Nil(tostring(err):match('Could not write'))
      assert.are.same(case.lines, vim.fn.readfile(target.filename))
      assert.are.same(0, vim.fn.bufexists(target.filename))
    end)
  end

  it('acts on its own headline when a read autocmd of an unloaded file inserts a headline above', function()
    local target = helpers.create_agenda_file({ '* TODO A', '* TODO B' })
    local target_bufnr = vim.fn.bufnr(target.filename)
    helpers.create_file({ '* TODO Other buffer' })
    vim.cmd('bunload ' .. target_bufnr)
    local headline = api.load(target.filename).headlines[2]
    local group = vim.api.nvim_create_augroup('test_read_autocmd_inserts_headline', { clear = true })
    vim.api.nvim_create_autocmd('BufReadPost', {
      group = group,
      pattern = '*.org',
      callback = function(args)
        if args.buf == target_bufnr then
          vim.api.nvim_buf_set_lines(args.buf, 0, 0, false, { '* TODO Inserted' })
        end
      end,
    })

    local ok, err = pcall(function()
      headline:set_tags({ 'x' }):wait()
    end)

    assert.is.True(ok, err)
    local lines = vim.fn.readfile(target.filename)
    assert.are.same({ '* TODO Inserted', '* TODO A' }, { lines[1], lines[2] })
    assert.is.Not.Nil(lines[3]:match('^%* TODO B%s+:x:$'))
  end)

  it('changes nothing when a read autocmd of an unloaded file removes the headline of the handle', function()
    local target = helpers.create_agenda_file({ '* TODO A', '* TODO B' })
    local target_bufnr = vim.fn.bufnr(target.filename)
    helpers.create_file({ '* TODO Other buffer' })
    vim.cmd('bunload ' .. target_bufnr)
    local headline = api.load(target.filename).headlines[2]
    local group = vim.api.nvim_create_augroup('test_read_autocmd_removes_headline', { clear = true })
    vim.api.nvim_create_autocmd('BufReadPost', {
      group = group,
      pattern = '*.org',
      callback = function(args)
        if args.buf == target_bufnr then
          vim.api.nvim_buf_set_lines(args.buf, 1, 2, false, { '* TODO C' })
        end
      end,
    })

    local ok, err = pcall(function()
      headline:set_tags({ 'x' }):wait()
    end)

    assert.is.False(ok)
    assert.is.Not.Nil(tostring(err):match('Headline "%* TODO B" not found'))
    assert.are.same({ '* TODO A', '* TODO B' }, vim.fn.readfile(target.filename))
  end)

  it('returns to the current window when an api mutation on another file fails', function()
    local target = helpers.create_agenda_file({ '* TODO Target' })
    helpers.create_file({ '* TODO Other buffer' })
    local win = vim.api.nvim_get_current_win()
    local headline = api.load(target.filename).headlines[1]

    local ok = pcall(function()
      headline:set_deadline('garbage'):wait()
    end)

    assert.is.False(ok)
    assert.are.same(win, vim.api.nvim_get_current_win())
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

  for _, case in ipairs({
    {
      name = 'a file without a buffer',
      setup = function(bufnr)
        vim.cmd('bwipeout ' .. bufnr)
      end,
    },
    {
      name = 'a listed unloaded buffer',
      setup = function(bufnr)
        vim.cmd('bunload ' .. bufnr)
      end,
    },
    { name = 'a hidden buffer without unsaved edits', setup = function() end },
  }) do
    it('saves an api mutation on ' .. case.name .. ' when an enter autocmd edits the buffer', function()
      local target = helpers.create_agenda_file({ '* TODO Target' })
      helpers.create_file({ '* TODO Other buffer' })
      case.setup(vim.fn.bufnr(target.filename))
      local headline = api.load(target.filename).headlines[1]
      local edited = false
      vim.api.nvim_create_autocmd('BufEnter', {
        group = vim.api.nvim_create_augroup('test_enter_autocmd_edits', { clear = true }),
        pattern = '*.org',
        callback = function(args)
          if not edited and args.buf == vim.fn.bufnr(target.filename) then
            edited = true
            vim.api.nvim_buf_set_lines(args.buf, -1, -1, false, { 'hooked' })
          end
        end,
      })

      local ok, err = pcall(function()
        headline:set_tags({ 'x' }):wait()
      end)

      assert.is.True(ok, err)
      assert.is.True(edited)
      local lines = vim.fn.readfile(target.filename)
      assert.is.Not.Nil(lines[1]:match('^%* TODO Target%s+:x:$'))
      assert.are.same({ 'hooked' }, { lines[2] })
      local bufnr = vim.fn.bufnr(target.filename)
      assert.is.False(bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].modified)
    end)
  end

  for _, case in ipairs({
    { name = 'count', before = '* Project [0/2]', after = '* Project [1/2]' },
    { name = 'percent', before = '* Project [0%]', after = '* Project [50%]' },
  }) do
    it(
      'finds a handle without an id after setting a sibling to DONE updated the '
        .. case.name
        .. ' cookie of the parent',
      function()
        helpers.create_file({ case.before, '** TODO A', '** TODO B' })
        local b = cur_file().headlines[3]
        vim.fn.cursor(2, 1)
        vim.cmd([[norm cit]])
        assert.are.same(case.after, vim.fn.getline(1))

        local ok, err = pcall(function()
          b:set_tags({ 'x' }):wait()
        end)

        assert.is.True(ok, err)
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        assert.is.Not.Nil(lines[#lines]:match('^%*%* TODO B%s+:x:$'))
      end
    )
  end

  it('finds a handle without an id after setting a child to DONE updated the cookie on its own line', function()
    helpers.create_file({ '* TODO Project [0/2]', '** TODO A', '** TODO B' })
    local project = cur_file().headlines[1]
    vim.fn.cursor(2, 1)
    vim.cmd([[norm cit]])
    assert.are.same('* TODO Project [1/2]', vim.fn.getline(1))

    local ok, err = pcall(function()
      project:set_tags({ 'x' }):wait()
    end)

    assert.is.True(ok, err)
    assert.is.Not.Nil(vim.fn.getline(1):match('^%* TODO Project %[1/2%]%s+:x:$'))
  end)

  it('keeps a handle with a cookie on its headline after a write hook inserted a line above', function()
    local inserted = false
    vim.api.nvim_create_autocmd('BufWritePre', {
      group = vim.api.nvim_create_augroup('OrgApiHandleCookieInsertHook', { clear = true }),
      callback = function()
        if inserted then
          return
        end
        inserted = true
        vim.api.nvim_buf_set_lines(0, 0, 0, false, { '#+TITLE: Hooked' })
      end,
    })
    helpers.create_file({
      '* TODO First [1/2]',
      '* TODO Second',
    })
    local first = cur_file().headlines[1]

    local ok, err = pcall(function()
      first:set_priority('A'):wait()
    end)

    assert.is.True(ok, err)
    assert.are.same(2, first.position.start_line)
    assert.is.Not.Nil(vim.fn.getline(2):match('^%* TODO %[#A%] First %[1/2%]$'))
  end)
end)

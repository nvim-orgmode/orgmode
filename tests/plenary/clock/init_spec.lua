local OrgFiles = require('orgmode.files')
local OrgFile = require('orgmode.files.file')
local Files = require('orgmode.parser.files')
local org = require('orgmode')

describe('Clock', function()
  ---@return OrgFile
  local load_file_sync = function(content, filename)
    content = content or {}
    filename = filename or vim.fn.tempname() .. '.org'
    vim.fn.writefile(content, filename)
    return OrgFile.load(filename):wait()
  end

  it('should properly close out an existing clock when clocking in a new headline', function()
    local file = load_file_sync({
      '* TODO Test 1',
      '  :LOGBOOK:',
      '  CLOCK: [2024-05-22 Wed 05:15]',
      '  :END:',
      '* TODO Test 2',
    })

    vim.cmd('edit ' .. file.filename)

    Files.file_loader = OrgFiles:new({
      paths = { file.filename },
    })
    local files = Files.loader()
    files:add_to_paths(file.filename):wait()

    -- Establish baseline: Test 1 is clocked in
    local clock = org.clock:new({ files = files })
    assert.are.same('Test 1', clock.clocked_headline:get_title())
    assert.is_true(clock.clocked_headline:is_clocked_in())

    -- Move the test 2 header above test 1 and then clock test 2 in
    vim.fn.cursor({ 5, 1 })
    vim.cmd('normal! dd')
    vim.fn.cursor({ 1, 1 })
    vim.cmd('normal! P')
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
end)

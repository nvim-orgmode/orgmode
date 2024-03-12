local config = require('orgmode.config')
local helpers = require('tests.plenary.helpers')

-- Helper assert function.
local function expect_whole_buffer(expected)
  assert.are.same(expected, vim.api.nvim_buf_get_lines(0, 0, -1, false))
end

-- We want to run all tests under both values for `org_startup_indented`: "true"
-- and "false". So it is easier to put all tests into test functions and
-- check the indent mode, then run them under two different `describe()`.

local function test_full_reindent()
  local unformatted_file = {
    '* TODO First task',
    'SCHEDULED: <1970-01-01 Thu>',
    '',
    '1. Ordered list',
    '   a) nested list',
    '          over-indented',
    '          over-indented',
    '   b) nested list',
    '    under-indented',
    '2. Ordered list',
    'Not part of the list',
    '',
    '** Second task',
    '         DEADLINE: <1970-01-01 Thu>',
    '',
    '- Unordered list',
    '  + nested list',
    '        over-indented',
    '        over-indented',
    '  + nested list',
    '   under-indented',
    '- unordered list',
    ' + nested list',
    '  * triple nested list',
    '    continuation',
    ' part of the first-level list',
    'Not part of the list',
    '',
    '*** Incorrectly indented block',
    '     #+BEGIN_SRC json',
    ' {',
    '   "key": "value",',
    '   "another key": "another value"',
    ' }',
    '     #+END_SRC',
    '',
    '    - Correctly reindents to list indentation level',
    '                #+BEGIN_SRC json',
    '      {',
    '        "key": "value",',
    '        "another key": "another value"',
    '      }',
    '#+END_SRC',
    '    - Correctly reindents when entire block overindented',
    '         #+BEGIN_SRC json',
    '         {',
    '           "key": "value",',
    '           "another key": "another value"',
    '         }',
    '         #+END_SRC',
    '    - Correctly maintains indentation when single line is at the same level as header and rest is overindented',
    '      #+BEGIN_SRC json',
    '      {',
    '           "key": "value",',
    '           "another key": "another value"',
    '               }',
    '      #+END_SRC',
    '    - Correctly ignores blank lines for calculating indentation',
    '      #+BEGIN_SRC json',
    '',
    '          {',
    '            "key": "value",',
    '',
    '            "another key": "another value"',
    '          }',
    '',
    '      #+END_SRC',
  }
  helpers.create_file(unformatted_file)
  vim.cmd([[silent norm 0gg=G]])
  local expected
  if config.org_adapt_indentation then
    expected = {
      '* TODO First task',
      '  SCHEDULED: <1970-01-01 Thu>',
      '',
      '  1. Ordered list',
      '     a) nested list',
      '        over-indented',
      '        over-indented',
      '     b) nested list',
      '        under-indented',
      '  2. Ordered list',
      '  Not part of the list',
      '',
      '** Second task',
      '   DEADLINE: <1970-01-01 Thu>',
      '',
      '   - Unordered list',
      '     + nested list',
      '       over-indented',
      '       over-indented',
      '     + nested list',
      '       under-indented',
      '   - unordered list',
      '     + nested list',
      '       * triple nested list',
      '         continuation',
      '     part of the first-level list',
      '   Not part of the list',
      '',
      '*** Incorrectly indented block',
      '    #+BEGIN_SRC json',
      '    {',
      '      "key": "value",',
      '      "another key": "another value"',
      '    }',
      '    #+END_SRC',
      '',
      '    - Correctly reindents to list indentation level',
      '      #+BEGIN_SRC json',
      '      {',
      '        "key": "value",',
      '        "another key": "another value"',
      '      }',
      '      #+END_SRC',
      '    - Correctly reindents when entire block overindented',
      '      #+BEGIN_SRC json',
      '      {',
      '        "key": "value",',
      '        "another key": "another value"',
      '      }',
      '      #+END_SRC',
      '    - Correctly maintains indentation when single line is at the same level as header and rest is overindented',
      '      #+BEGIN_SRC json',
      '      {',
      '           "key": "value",',
      '           "another key": "another value"',
      '               }',
      '      #+END_SRC',
      '    - Correctly ignores blank lines for calculating indentation',
      '      #+BEGIN_SRC json',
      '',
      '      {',
      '        "key": "value",',
      '',
      '        "another key": "another value"',
      '      }',
      '',
      '      #+END_SRC',
    }
  else
    expected = {
      '* TODO First task',
      'SCHEDULED: <1970-01-01 Thu>',
      '',
      '1. Ordered list',
      '   a) nested list',
      '      over-indented',
      '      over-indented',
      '   b) nested list',
      '      under-indented',
      '2. Ordered list',
      'Not part of the list',
      '',
      '** Second task',
      'DEADLINE: <1970-01-01 Thu>',
      '',
      '- Unordered list',
      '  + nested list',
      '    over-indented',
      '    over-indented',
      '  + nested list',
      '    under-indented',
      '- unordered list',
      '  + nested list',
      '    * triple nested list',
      '      continuation',
      '  part of the first-level list',
      'Not part of the list',
      '',
      '*** Incorrectly indented block',
      '#+BEGIN_SRC json',
      '{',
      '  "key": "value",',
      '  "another key": "another value"',
      '}',
      '#+END_SRC',
      '',
      '- Correctly reindents to list indentation level',
      '  #+BEGIN_SRC json',
      '  {',
      '    "key": "value",',
      '    "another key": "another value"',
      '  }',
      '  #+END_SRC',
      '- Correctly reindents when entire block overindented',
      '  #+BEGIN_SRC json',
      '  {',
      '    "key": "value",',
      '    "another key": "another value"',
      '  }',
      '  #+END_SRC',
      '- Correctly maintains indentation when single line is at the same level as header and rest is overindented',
      '  #+BEGIN_SRC json',
      '  {',
      '       "key": "value",',
      '       "another key": "another value"',
      '           }',
      '  #+END_SRC',
      '- Correctly ignores blank lines for calculating indentation',
      '  #+BEGIN_SRC json',
      '',
      '  {',
      '    "key": "value",',
      '',
      '    "another key": "another value"',
      '  }',
      '',
      '  #+END_SRC',
    }
  end
  expect_whole_buffer(expected)
end

local function test_newly_written_list()
  helpers.create_file({})
  local user_input = vim.api.nvim_replace_termcodes('i- new item<CR>second line<CR>third line<Esc>', true, true, true)
  vim.api.nvim_feedkeys(user_input, 'ntix', false)
  local expected = {
    '- new item',
    '  second line',
    '  third line',
  }
  expect_whole_buffer(expected)
end

local function test_insertion_to_an_existing_list()
  helpers.create_file({ '- first item', '- third item' })
  vim.cmd([[normal! o]])
  local user_input = vim.api.nvim_replace_termcodes('i- new item<CR>second line<CR>third line<Esc>', true, true, true)
  vim.api.nvim_feedkeys(user_input, 'ntix', false)
  local expected = {
    '- first item',
    '- new item',
    '  second line',
    '  third line',
    '- third item',
  }
  expect_whole_buffer(expected)
end

local function test_add_line_breaks_to_existing_file()
  helpers.create_file({ '- first item', '- second item' })
  local user_input = vim.api.nvim_replace_termcodes('wwi<CR><Esc><Down><Right>i<CR><Esc>', true, true, true)
  vim.api.nvim_feedkeys(user_input, 'ntix', false)
  local expected = {
    '- first ',
    '  item',
    '- ',
    '  second item',
  }
  expect_whole_buffer(expected)
end

-- The actual tests are here.

describe('with "indent",', function()
  before_each(function()
    config:extend({ org_startup_indented = true })
  end)

  it('"0gg=G" reindents the whole file', function()
    test_full_reindent()
  end)

  it('a newly written list is well indented', function()
    test_newly_written_list()
  end)

  it('insertion to an existing list is well indented', function()
    test_insertion_to_an_existing_list()
  end)

  it('adding line breaks to list items maintains indent', function()
    test_add_line_breaks_to_existing_file()
  end)
end)

describe('with "noindent",', function()
  before_each(function()
    config:extend({ org_startup_indented = false })
  end)

  it('"0gg=G" reindents the whole file', function()
    test_full_reindent()
  end)

  it('a newly written list is well indented', function()
    test_newly_written_list()
  end)

  it('insertion into an existing list is well indented', function()
    test_insertion_to_an_existing_list()
  end)

  it('adding line breaks to list items maintains indent', function()
    test_add_line_breaks_to_existing_file()
  end)
end)

describe('with "indent" and "VirtualIndent" is enabled', function()
  before_each(function()
    config:extend({ org_startup_indented = true })
  end)

  it('has the correct amount of virtual indentation', function()
    if not vim.b.org_indent_mode then
      return
    end

    -- In order: { content, virtcol }
    -- See `:h virtcol` for details
    local content_virtcols = {
      { '* TODO First task', 1 },
      { 'SCHEDULED: <1970-01-01 Thu>', 3 },
      { '', 2 },
      { '1. Ordered list', 3 },
      { '   a) nested list', 3 },
      { '      over-indented', 3 },
      { '      over-indented', 3 },
      { '   b) nested list', 3 },
      { '      under-indented', 3 },
      { '2. Ordered list', 3 },
      { 'Not part of the list', 3 },
      { '', 2 },
      { '** Second task', 1 },
      { 'DEADLINE: <1970-01-01 Thu>', 4 },
      { '', 3 },
      { '- Unordered list', 4 },
      { '  + nested list', 4 },
      { '    over-indented', 4 },
      { '    over-indented', 4 },
      { '  + nested list', 4 },
      { '    under-indented', 4 },
      { '- unordered list', 4 },
      { '  + nested list', 4 },
      { '    * triple nested list', 4 },
      { '      continuation', 4 },
      { '  part of the first-level list', 4 },
      { 'Not part of the list', 4 },
      { '', 3 },
      { '*** Incorrectly indented block', 1 },
      { '#+BEGIN_SRC json', 5 },
      { '{', 5 },
      { '  "key": "value",', 5 },
      { '  "another key": "another value"', 5 },
      { '}', 5 },
      { '#+END_SRC', 5 },
      { '', 4 },
      { '- Correctly reindents to list indentation level', 5 },
      { '  #+BEGIN_SRC json', 5 },
      { '  {', 5 },
      { '    "key": "value",', 5 },
      { '    "another key": "another value"', 5 },
      { '  }', 5 },
      { '  #+END_SRC', 5 },
      { '- Correctly reindents when entire block overindented', 5 },
      { '  #+BEGIN_SRC json', 5 },
      { '  {', 5 },
      { '    "key": "value",', 5 },
      { '    "another key": "another value"', 5 },
      { '  }', 5 },
      { '  #+END_SRC', 5 },
    }
    local content = {}
    for _, content_virtcol in pairs(content_virtcols) do
      table.insert(content, content_virtcol[1])
    end
    helpers.create_file(content)

    for line = 1, vim.api.nvim_buf_line_count(0) do
      vim.api.nvim_win_set_cursor(0, { line, 0 })
      assert.are.same(content_virtcols[line][1], vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1])
      assert.are.equal(content_virtcols[line][2], vim.fn.virtcol('.'))
    end
  end)

  it('Virtual Indent detaches and reattaches in response to toggling `vim.b.org_indent_mode`', function()
    if not vim.b.org_indent_mode then
      return
    end

    local content_virtcols = {
      { '* TODO First task', 1 },
      { 'SCHEDULED: <1970-01-01 Thu>', 3 },
      { '', 2 },
      { '1. Ordered list', 3 },
      { '   a) nested list', 3 },
      { '      over-indented', 3 },
      { '      over-indented', 3 },
      { '   b) nested list', 3 },
      { '      under-indented', 3 },
      { '2. Ordered list', 3 },
      { 'Not part of the list', 3 },
      { '', 2 },
      { '** Second task', 1 },
      { 'DEADLINE: <1970-01-01 Thu>', 4 },
      { '', 3 },
      { '- Unordered list', 4 },
      { '  + nested list', 4 },
      { '    over-indented', 4 },
      { '    over-indented', 4 },
      { '  + nested list', 4 },
      { '    under-indented', 4 },
      { '- unordered list', 4 },
      { '  + nested list', 4 },
      { '    * triple nested list', 4 },
      { '      continuation', 4 },
      { '  part of the first-level list', 4 },
      { 'Not part of the list', 4 },
      { '', 3 },
      { '*** Incorrectly indented block', 1 },
      { '#+BEGIN_SRC json', 5 },
      { '{', 5 },
      { '  "key": "value",', 5 },
      { '  "another key": "another value"', 5 },
      { '}', 5 },
      { '#+END_SRC', 5 },
      { '', 4 },
      { '- Correctly reindents to list indentation level', 5 },
      { '  #+BEGIN_SRC json', 5 },
      { '  {', 5 },
      { '    "key": "value",', 5 },
      { '    "another key": "another value"', 5 },
      { '  }', 5 },
      { '  #+END_SRC', 5 },
      { '- Correctly reindents when entire block overindented', 5 },
      { '  #+BEGIN_SRC json', 5 },
      { '  {', 5 },
      { '    "key": "value",', 5 },
      { '    "another key": "another value"', 5 },
      { '  }', 5 },
      { '  #+END_SRC', 5 },
    }
    local content = {}
    for _, content_virtcol in pairs(content_virtcols) do
      table.insert(content, content_virtcol[1])
    end
    helpers.create_file(content)

    -- Check if VirtualIndent correctly detaches in response to disabling `vim.b.org_indent_mode`
    vim.b.org_indent_mode = false
    -- Give VirtualIndent long enough to react to the change in `vim.b.org_indent_mode`
    vim.wait(60)
    for line = 1, vim.api.nvim_buf_line_count(0) do
      vim.api.nvim_win_set_cursor(0, { line, 0 })
      assert.are.equal(0, vim.fn.virtcol('.'))
    end

    -- Check if VirtualIndent correctly attaches in response to disabling `vim.b.org_indent_mode`
    vim.b.org_indent_mode = true
    -- Give VirtualIndent long enough to react to the change in `vim.b.org_indent_mode`
    vim.wait(60)
    for line = 1, vim.api.nvim_buf_line_count(0) do
      vim.api.nvim_win_set_cursor(0, { line, 0 })
      assert.are.same(content_virtcols[line][1], vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1])
      assert.are.equal(content_virtcols[line][2], vim.fn.virtcol('.'))
    end
  end)
end)

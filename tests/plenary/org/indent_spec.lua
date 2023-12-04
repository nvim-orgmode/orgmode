local config = require('orgmode.config')
local Indent = require('orgmode.org.indent')
local helpers = require('tests.plenary.ui.helpers')

-- Helper assert function.
local function expect_whole_buffer(expected)
  assert.are.same(expected, vim.api.nvim_buf_get_lines(0, 0, -1, false))
end

-- We want to run all tests under both values for `org_indent_mode`: "indent"
-- and "noindent". So it is easier to put all tests into test functions and
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
  }
  helpers.load_file_content(unformatted_file)
  vim.cmd([[silent norm 0gg=G]])
  local expected
  if config.org_indent_mode == 'indent' then
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
    }
  elseif config.org_indent_mode == 'noindent' then
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
    }
  end
  expect_whole_buffer(expected)
end

local function test_newly_written_list()
  helpers.load_file_content({})
  local user_input = vim.api.nvim_replace_termcodes('i- new item<CR>second line<CR>third line<Esc>', true, true, true)
  vim.api.nvim_feedkeys(user_input, 'ntix', false)
  local expected
  if config.org_indent_mode == 'indent' then
    expected = {
      '- new item',
      '  second line',
      '  third line',
    }
  elseif config.org_indent_mode == 'noindent' then
    expected = {
      '- new item',
      '  second line',
      '  third line',
    }
  end
  expect_whole_buffer(expected)
end

local function test_insertion_to_an_existing_list()
  helpers.load_file_content({ '- first item', '- third item' })
  vim.cmd([[normal! o]])
  local user_input = vim.api.nvim_replace_termcodes('i- new item<CR>second line<CR>third line<Esc>', true, true, true)
  vim.api.nvim_feedkeys(user_input, 'ntix', false)
  local expected
  if config.org_indent_mode == 'indent' then
    expected = {
      '- first item',
      '- new item',
      '  second line',
      '  third line',
      '- third item',
    }
  elseif config.org_indent_mode == 'noindent' then
    expected = {
      '- first item',
      '- new item',
      '  second line',
      '  third line',
      '- third item',
    }
  end
  expect_whole_buffer(expected)
end

local function test_add_line_breaks_to_existing_file()
  helpers.load_file_content({ '- first item', '- second item' })
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
    config:extend({ org_indent_mode = 'indent' })
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
    config:extend({ org_indent_mode = 'noindent' })
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

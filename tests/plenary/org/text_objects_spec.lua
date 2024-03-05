local helpers = require('tests.plenary.helpers')

--- Inserts a string into another and returns the newly created combined string
---@param string_to_insert_into string The string to modify
---@param string_to_be_inserted string The string to insert
---@param pos integer The 1-indexed position to insert a string at
---@return string combined A string with the new substring inserted at the given pos
local function insert_substring(string_to_insert_into, string_to_be_inserted, pos)
  local split_str = {}
  ---@diagnostic disable-next-line: discard-returns
  string_to_insert_into:gsub('.', function(c)
    table.insert(split_str, c)
  end)
  table.insert(split_str, pos, string_to_be_inserted)
  return table.concat(split_str)
end

---Loop through a given string and compare the custom textobject operation to Vim's builtin
---operation and assert they are the same
---@param marker string A single character textobject marker to use in operation
---@param around boolean Whether or not to use the `around` operation or `inner` operation
---@param content string A template string to use for the operations, place `%` signs where the marker should be inserted
---@param builtin_marker? string A single character textobject marker that is builtin to vim, default: "
local function expect_text_object(marker, around, content, builtin_marker)
  builtin_marker = builtin_marker or '"'
  if #builtin_marker > 1 then
    error(
      'Comparator token textobject may only be `1` in length. It should be a builtin token from Vim\'s textobjects like `"`.'
    )
  end
  local comparator_content = content:gsub('%%', builtin_marker)
  content = content:gsub('%%', marker)

  local command = 'normal d' .. (around and 'a' or 'i')
  helpers.create_file({})
  -- Move one-by-one along the line and run a textobject operation at each position and compare
  -- against a vim built-in textobject operation.
  for cursor_col = 1, #content do
    -- Run the text object actions with a vim built-in textobject so we know what the actual content
    -- should become
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { comparator_content })
    vim.api.nvim_win_set_cursor(0, { 1, cursor_col - 1 })
    vim.cmd(command .. builtin_marker)
    local expected = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    expected = vim.tbl_map(function(line)
      return line:gsub('%' .. builtin_marker, marker)
    end, expected)

    -- Run the text object actions with the custom marker and capture the output
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { content })
    vim.api.nvim_win_set_cursor(0, { 1, cursor_col - 1 })
    vim.cmd(command .. marker)
    local curr_content = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    if not vim.deep_equal(expected, curr_content) then
      ---@diagnostic disable-next-line: undefined-field
      assert.are
        .message(table.concat({
          '\nTest Failed For Marker: ' .. vim.inspect(marker),
          'Command: ' .. vim.inspect(command .. marker),
          'Cursor col: ' .. vim.inspect(cursor_col),
          'Given Content:         ' .. vim.inspect(content),
          'Cursor (|) in Content: ' .. vim.inspect(insert_substring(content, '|', cursor_col)),
        }, '\n  '))
        .same(expected, curr_content)
    end
  end
end

local emphasis_markers = {
  '_',
  '=',
  '/',
  '+',
  '*',
  '~',
}

for _, emphasis_marker in ipairs(emphasis_markers) do
  describe('The emphasis around textobject `' .. emphasis_marker .. '`', function()
    local around = true

    it('correctly selects the same as `"` in all line column positions with unbalanced pairs', function()
      expect_text_object(emphasis_marker, around, [[-> %Hello% World%   %End%]])
    end)

    it('correctly selects the same as `"` in all line column positions with balanced pairs', function()
      expect_text_object(emphasis_marker, around, [[-> %Hello% %World%   %End%]])
    end)

    it(
      'correctly selects the same as `"` in all line column positions with limited whitespace with balanced pairs',
      function()
        expect_text_object(emphasis_marker, around, [[-> %Hello% %World%words%End%]])
      end
    )

    it(
      'correctly selects the same as `"` in all line column positions with limited whitespace with unbalanced pairs',
      function()
        expect_text_object(emphasis_marker, around, [[-> %Hello%World%words%End%]])
      end
    )

    it(
      'correctly selects the same as `"` in all line column positions with no whitespace with balanced pairs',
      function()
        expect_text_object(emphasis_marker, around, [[-> %Hello% %World%words%End%]])
      end
    )

    it(
      'correctly selects the same as `"` in all line column positions with no whitespace with unbalanced pairs',
      function()
        expect_text_object(emphasis_marker, around, [[-> %Hello%World%words%End%]])
      end
    )
  end)

  describe('The emphasis inner textobject `' .. emphasis_marker .. '`', function()
    local around = false
    it('correctly selects the same as `"` in all line column positions with unbalanced pairs', function()
      expect_text_object(emphasis_marker, around, [[-> %Hello% World%   %End%]])
    end)

    it('correctly selects the same as `"` in all line column positions with balanced pairs', function()
      expect_text_object(emphasis_marker, around, [[-> %Hello% %World%   %End%]])
    end)

    it(
      'correctly selects the same as `"` in all line column positions with limited whitespace with balanced pairs',
      function()
        expect_text_object(emphasis_marker, around, [[-> %Hello% %World%words%End%]])
      end
    )

    it(
      'correctly selects the same as `"` in all line column positions with limited whitespace with unbalanced pairs',
      function()
        expect_text_object(emphasis_marker, around, [[-> %Hello% World%words%End%]])
      end
    )

    it(
      'correctly selects the same as `"` in all line column positions with no whitespace with balanced pairs',
      function()
        expect_text_object(emphasis_marker, around, [[-> %Hello% %World%words%End%]])
      end
    )

    it(
      'correctly selects the same as `"` in all line column positions with no whitespace with unbalanced pairs',
      function()
        expect_text_object(emphasis_marker, around, [[-> %Hello%World%words%End%]])
      end
    )
  end)
end

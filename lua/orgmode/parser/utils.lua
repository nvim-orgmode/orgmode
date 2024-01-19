local M = {}

---Parses a pattern from the beginning of an input using Lua's pattern syntax
---@param input string
---@param pattern string
---@return string?, string
function M.parse_pattern(input, pattern)
  local value = input:match('^' .. pattern)
  if value then
    return value, input:sub(#value + 1)
  else
    return nil, input
  end
end

---Parses the first of a sequence of patterns
---@param input string The input to parse
---@param ... string The patterns to accept
---@return string?, string
function M.parse_pattern_choice(input, ...)
  for _, pattern in ipairs({ ... }) do
    local value, remaining = M.parse_pattern(input, pattern)
    if value then
      return value, remaining
    end
  end

  return nil, input
end

---@generic T
---@param input string
---@param item_parser fun(input: string): (T?, string)
---@param delimiter_pattern string
---@return (T[])?, string
function M.parse_delimited_sequence(input, item_parser, delimiter_pattern)
  local sequence, item, delimiter = {}, nil, nil
  local original_input = input

  -- Parse the first item
  item, input = item_parser(input)
  if not item then
    return sequence, input
  end
  table.insert(sequence, item)

  --- @type string
  local snapshot = input

  -- Continue parsing items while there's a trailing delimiter
  delimiter, input = M.parse_pattern(input, delimiter_pattern)
  while delimiter do
    item, input = item_parser(input)

    -- If not another element, eturn the previously parsed items
    if not item then
      return sequence, snapshot
    end

    table.insert(sequence, item)
    snapshot = input

    delimiter, input = M.parse_pattern(input, delimiter_pattern)
  end

  return sequence, input
end

return M

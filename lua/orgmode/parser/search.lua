--TODO: Support regex search

local Date = require('orgmode.objects.date')

---@class Search
---@field term string
---@field expressions table
---@field logic OrItem[]
---@field todo_search table
local Search = {}

---@class Searchable
---@field props table<string, string>
---@field tags string[]
---@field todo string

---@class OrItem
---@field and_items AndItem[]
local OrItem = {}
OrItem.__index = OrItem

---@class AndItem
---@field contains Matchable[]
---@field excludes Matchable[]
local AndItem = {}
AndItem.__index = AndItem

---@alias Matchable TagMatch|PropertyMatch

---@class TagMatch
---@field value string
local TagMatch = {}
TagMatch.__index = TagMatch

---@alias PropertyMatch PropertyDateMatch|PropertyStringMatch|PropertyNumberMatch
local PropertyMatch = {}
PropertyMatch.__index = PropertyMatch

---@alias PropertyMatchOperator '='|'<>'|'<'|'<='|'>'|'>='

---@class PropertyDateMatch
---@field name string
---@field operator PropertyMatchOperator
---@field value Date
local PropertyDateMatch = {}
PropertyDateMatch.__index = PropertyDateMatch

---@class PropertyStringMatch
---@field name string
---@field operator PropertyMatchOperator
---@field value string
local PropertyStringMatch = {}
PropertyStringMatch.__index = PropertyStringMatch

---@class PropertyNumberMatch
---@field name string
---@field operator PropertyMatchOperator
---@field value number
local PropertyNumberMatch = {}
PropertyNumberMatch.__index = PropertyNumberMatch

---@type table<PropertyMatchOperator, fun(a: string|number|Date, b: string|number|Date): boolean>
local OPERATORS = {
  ['='] = function(a, b)
    return a == b
  end,
  ['<='] = function(a, b)
    return a <= b
  end,
  ['<'] = function(a, b)
    return a < b
  end,
  ['>='] = function(a, b)
    return a >= b
  end,
  ['>'] = function(a, b)
    return a > b
  end,
  ['<>'] = function(a, b)
    return a ~= b
  end,
}

---Parses a pattern from the beginning of an input using Lua's pattern syntax
---@param input string
---@param pattern string
---@return string?, string
local function parse_pattern(input, pattern)
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
local function parse_pattern_choice(input, ...)
  for _, pattern in ipairs({ ... }) do
    local value, remaining = parse_pattern(input, pattern)
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
local function parse_delimited_sequence(input, item_parser, delimiter_pattern)
  local sequence, item, delimiter = {}, nil, nil
  local original_input = input

  -- Parse the first item
  item, input = item_parser(input)
  if not item then
    return sequence, input
  end
  table.insert(sequence, item)

  -- Continue parsing items while there's a trailing delimiter
  delimiter, input = parse_pattern(input, delimiter_pattern)
  while delimiter do
    item, input = item_parser(input)
    if not item then
      return nil, original_input
    end

    table.insert(sequence, item)

    delimiter, input = parse_pattern(input, delimiter_pattern)
  end

  return sequence, input
end

---@param term string
---@return Search
function Search:new(term)
  ---@type Search
  local data = {
    term = term,
    expressions = {},
    logic = {},
    todo_search = nil,
  }
  setmetatable(data, self)
  self.__index = self
  data:_parse()

  return data
end

---@param item Searchable
---@return boolean
function Search:check(item)
  for _, or_item in ipairs(self.logic) do
    if or_item:match(item) then
      return true
    end
  end
  return false
end

---@private
function Search:_parse()
  -- Parse the sequence of ORs
  self.logic = parse_delimited_sequence(self.term, function(i)
    return OrItem:parse(i)
  end, '%|')

  -- If the sequence failed to parse, reset the array
  if not self.logic then
    self.logic = {}
  end
end

---@private
---@return OrItem
function OrItem:_new()
  ---@type OrItem
  local or_item = {
    and_items = {},
  }

  setmetatable(or_item, OrItem)
  return or_item
end

---@param input string
---@return OrItem?, string
function OrItem:parse(input)
  ---@type AndItem[]?
  local and_items
  local original_input = input

  and_items, input = parse_delimited_sequence(input, function()
    return AndItem:parse(input)
  end, '%&')

  if not and_items then
    return nil, original_input
  end

  local or_item = OrItem:_new()
  or_item.and_items = and_items

  return or_item, input
end

---Verifies that each AndItem contained within the OrItem matches
---@param item Searchable
---@return boolean
function OrItem:match(item)
  for _, and_item in ipairs(self.and_items) do
    if not and_item:match(item) then
      return false
    end
  end

  return true
end

---@private
---@return AndItem
function AndItem:_new()
  ---@type AndItem
  local and_item = {
    contains = {},
    excludes = {},
  }

  setmetatable(and_item, AndItem)
  return and_item
end

---@param input string
---@return AndItem?, string
function AndItem:parse(input)
  ---@type AndItem
  local and_item = AndItem:_new()
  ---@type string?
  local operator
  local original_input = input

  operator, input = parse_pattern(input, '[%+%-]?')

  -- A '+' operator is implied if none is present
  if operator == '' then
    operator = '+'
  end

  while operator do
    ---@type Matchable?
    local matchable

    -- Try to parse as a PropertyMatch first
    matchable, input = PropertyMatch:parse(input)

    -- If it wasn't a property match, then try a tag match
    if not matchable then
      matchable, input = TagMatch:parse(input)
      if not matchable then
        return nil, original_input
      end
    end

    if operator == '+' then
      table.insert(and_item.contains, matchable)
    elseif operator == '-' then
      table.insert(and_item.excludes, matchable)
    else
      -- This should never happen if I wrote the operator pattern correctly
    end

    -- Attempt to parse the next operator
    operator, input = parse_pattern(input, '[%+%-]')
  end

  return and_item, input
end

---@param item Searchable
---@return boolean
function AndItem:match(item)
  for _, c in ipairs(self.contains) do
    if not c:match(item) then
      return false
    end
  end

  for _, e in ipairs(self.excludes) do
    if e:match(item) then
      return false
    end
  end

  return true
end

---@private
---@param tag string
---@return TagMatch
function TagMatch:_new(tag)
  ---@type TagMatch
  local tag_match = { value = tag }
  setmetatable(tag_match, TagMatch)

  return tag_match
end

---@param input string
---@return TagMatch?, string
function TagMatch:parse(input)
  local tag
  tag, input = parse_pattern(input, '%w+')
  if not tag then
    return nil, input
  end

  return TagMatch:_new(tag), input
end

---@param item Searchable
---@return boolean
function TagMatch:match(item)
  for _, tag in ipairs(item.tags) do
    if tag == self.value then
      return true
    end
  end

  return false
end

---@param input string
---@return PropertyMatch?, string
function PropertyMatch:parse(input)
  ---@type string?, PropertyMatchOperator?
  local name, operator, string, number_str, date_str
  local original_input = input

  name, input = parse_pattern(input, '[^=<>]+')
  if not name then
    return nil, original_input
  end

  operator, input = self:_parse_operator(input)
  if not operator then
    return nil, original_input
  end

  -- Number property
  number_str, input = parse_pattern(input, '%d+')
  if number_str then
    local number = tonumber(number_str) --[[@as number]]
    return PropertyNumberMatch:new(name, operator, number), input
  end

  -- Date property
  date_str, input = parse_pattern(input, '"<[^>]+>"')
  if date_str then
    local unquoted_date_str = date_str:gsub('^"<', ''):gsub('>"$', '')
    ---@type Date?
    local date_value = Date.from_string(unquoted_date_str)
    if date_value then
      return PropertyDateMatch:new(name, operator, date_value), input
    else
      -- It could be a string query so reset the parse input
      input = date_str .. input
    end
  end

  -- String property
  string, input = parse_pattern(input, '"[^"]+"')
  if string then
    return PropertyStringMatch:new(name, operator, string), input
  end

  return nil, original_input
end

---@private
---Parses one of the comparison operators (=, <>, <, <=, >, >=)
---@param input string
---@return PropertyMatchOperator, string
function PropertyMatch:_parse_operator(input)
  return parse_pattern_choice(input, '%=', '%<%>', '%<', '%<%=', '%>', '%>%=') --[[@as PropertyMatchOperator]]
end

---Constructs a PropertyNumberMatch
---@param name string
---@param operator PropertyMatchOperator
---@param value number
---@return PropertyNumberMatch
function PropertyNumberMatch:new(name, operator, value)
  ---@type PropertyNumberMatch
  local number_match = {
    name = name,
    operator = operator,
    value = value,
  }

  setmetatable(number_match, PropertyNumberMatch)

  return number_match
end

---@param item Searchable
---@return boolean
function PropertyNumberMatch:match(item)
  local item_str_value = item.props[self.name]

  -- If the property in question is not a number, it's not a match
  local item_num_value = tonumber(item_str_value)
  if not item_num_value then
    return false
  end

  return OPERATORS[self.operator](item_num_value, self.value)
end

---@param name string
---@param operator PropertyMatchOperator
---@param value Date
---@return PropertyDateMatch
function PropertyDateMatch:new(name, operator, value)
  ---@type PropertyDateMatch
  local date_match = {
    name = name,
    operator = operator,
    value = value,
  }

  setmetatable(date_match, PropertyDateMatch)
  return date_match
end

---@param item Searchable
---@return boolean
function PropertyDateMatch:match(item)
  local should_print = item.props.foo

  if should_print then
    print('PropertyDateMatch:match(' .. vim.inspect(item) .. ')')
  end

  local item_value = item.props[self.name]

  -- If the property is missing, then it's not a match
  if not item_value then
    if should_print then
      print('No foo value contained')
    end
    return false
  end

  -- Extract the content between the braces/brackets
  local date_content = item_value:match('^[<%[]([^>%]]+)[>%]]$')
  if not date_content then
    if should_print then
      print('Failed to extract date content: "' .. item_value .. '"')
    end
    return false
  end

  ---@type Date?
  local item_date = Date.from_string(date_content)
  if not item_date then
    if should_print then
      print('Date did not parse: ' .. date_content)
    end
    return false
  end

  local result = OPERATORS[self.operator](item_date, self.value)
  if should_print then
    print('The result is ' .. vim.inspect(result))
  end

  return result
end

---@param name string
---@param operator PropertyMatchOperator
---@param value string
---@return PropertyStringMatch
function PropertyStringMatch:new(name, operator, value)
  ---@type PropertyStringMatch
  local string_match = {
    name = name,
    operator = operator,
    value = value,
  }

  setmetatable(string_match, PropertyStringMatch)

  return string_match
end

---@param item Searchable
---@return boolean
function PropertyStringMatch:match(item)
  local item_value = item.props[self.name] or ''
  return OPERATORS[self.operator](item_value, self.value)
end

return Search

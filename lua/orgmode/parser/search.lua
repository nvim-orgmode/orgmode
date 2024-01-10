--TODO: Support regex search

local Date = require('orgmode.objects.date')
local parsing = require('orgmode.parser.utils')

---@class Search
---@field term string
---@field expressions table
---@field or_items OrItem[]
---@field todo_search? TodoMatch
local Search = {}

---@class Searchable
---@field props table<string, string>
---@field tags string|string[]
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

---@class TodoMatch
---@field anyOf string[]
---@field noneOf string[]
local TodoMatch = {}
TodoMatch.__index = TodoMatch

---@type table<PropertyMatchOperator, fun(a: string|number|Date, b: string|number|Date): boolean>
local OPERATORS = {
  ['='] = function(a, b)
    local result = a == b
    return result
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

---@param term string
---@return Search
function Search:new(term)
  ---@type Search
  local data = {
    term = term,
    expressions = {},
    or_items = {},
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
  local ors_match = false
  for _, or_item in ipairs(self.or_items) do
    if or_item:match(item) then
      ors_match = true
      break
    end
  end

  local todos_match
  if self.todo_search then
    todos_match = self.todo_search:match(item)
  else
    todos_match = true
  end

  return ors_match and todos_match
end

---@private
function Search:_parse()
  local input = self.term
  -- Parse the sequence of ORs
  self.or_items, input = parsing.parse_delimited_sequence(input, function(i)
    return OrItem:parse(i)
  end, '%|')

  -- If the sequence failed to parse, reset the array
  self.or_items = self.or_items or {}

  -- Parse the TODO word filters if present
  self.todo_search, input = TodoMatch:parse(input)
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

  and_items, input = parsing.parse_delimited_sequence(input, function(i)
    return AndItem:parse(i)
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

  operator, input = parsing.parse_pattern(input, '[%+%-]?')

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
    operator, input = parsing.parse_pattern(input, '[%+%-]')
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
  tag, input = parsing.parse_pattern(input, '[%w_@#%%]+')
  if not tag then
    return nil, input
  end

  return TagMatch:_new(tag), input
end

---@param item Searchable
---@return boolean
function TagMatch:match(item)
  local item_tags = item.tags
  if type(item_tags) == 'string' then
    return item_tags == self.value
  end

  for _, tag in ipairs(item_tags) do
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
  local name, operator, string_str, number_str, date_str
  local original_input = input

  name, input = parsing.parse_pattern(input, '[^=<>]+')
  if not name then
    return nil, original_input
  end
  name = name:lower()

  operator, input = self:_parse_operator(input)
  if not operator then
    return nil, original_input
  end

  -- Number property
  number_str, input = parsing.parse_pattern(input, '%d+')
  if number_str then
    local number = tonumber(number_str) --[[@as number]]
    return PropertyNumberMatch:new(name, operator, number), input
  end

  -- Date property
  date_str, input = parsing.parse_pattern(input, '"(<[^>]+>)"')
  if date_str then
    ---@type string?, Date?
    local date_content, date_value
    if date_str == '<today>' then
      date_value = Date.today()
    elseif date_str == '<tomorrow>' then
      date_value = Date.tomorrow()
    else
      -- Parse relative formats (e.g. <+1d>) as well as absolute
      date_content = date_str:match('^<([%+%-]%d+[dmyhwM])>$')
      if date_content then
        date_value = Date.now()
        date_value = date_value:adjust(date_content)
      else
        date_content = date_str:match('^<([^>]+)>$')
        if date_content then
          date_value = Date.from_string(date_str)
        end
      end
    end

    ---@type Date?
    if date_value then
      return PropertyDateMatch:new(name, operator, date_value), input
    else
      -- It could be a string query so reset the parse input
      input = date_str .. input
    end
  end

  -- String property
  string_str, input = parsing.parse_pattern(input, '"[^"]+"')
  if string_str then
    ---@type string
    local unquote_string = string_str:match('^"([^"]+)"$')
    return PropertyStringMatch:new(name, operator, unquote_string), input
  end

  return nil, original_input
end

---@private
---Parses one of the comparison operators (=, <>, <, <=, >, >=)
---@param input string
---@return PropertyMatchOperator, string
function PropertyMatch:_parse_operator(input)
  return parsing.parse_pattern_choice(input, '%=', '%<%>', '%<%=', '%<', '%>%=', '%>') --[[@as PropertyMatchOperator]]
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
  local item_value = item.props[self.name]

  -- If the property is missing, then it's not a match
  if not item_value then
    return false
  end

  -- Extract the content between the braces/brackets
  local date_content = item_value:match('^[<%[]([^>%]]+)[>%]]$')
  if not date_content then
    return false
  end

  ---@type Date?
  local item_date = Date.from_string(date_content)
  if not item_date then
    return false
  end

  return OPERATORS[self.operator](item_date, self.value)
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

---@private
---@return TodoMatch
function TodoMatch:_new()
  ---@type TodoMatch
  local todo_match = {
    anyOf = {},
    noneOf = {},
  }

  setmetatable(todo_match, TodoMatch)

  return todo_match
end

---@param input string
---@return TodoMatch?, string
function TodoMatch:parse(input)
  local original_input = input

  -- Parse the '/' or '/!' prefix that indicates a TodoMatch
  ---@type string?
  local prefix
  prefix, input = parsing.parse_pattern(input, '%/[%!]?')
  if not prefix then
    return nil, original_input
  end

  -- Parse a whitelist of keywords
  --- @type string[]?
  local anyOf
  anyOf, input = parsing.parse_delimited_sequence(input, function(i)
    return parsing.parse_pattern(i, '%w+')
  end, '%|')
  if anyOf and #anyOf > 0 then
    -- Successfully parsed the whitelist, return it
    local todo_match = TodoMatch:_new()
    todo_match.anyOf = anyOf
    return todo_match, input
  end

  -- Parse a blacklist of keywords
  ---@type string?
  local negation
  negation, input = parsing.parse_pattern(input, '-')
  if negation then
    local negative_items
    negative_items, input = parsing.parse_delimited_sequence(input, function(i)
      return parsing.parse_pattern(i, '%w+')
    end, '%-')

    if negative_items then
      if #negation > 0 then
        local todo_match = TodoMatch:_new()
        todo_match.noneOf = negative_items
        return todo_match, input
      else
        return nil, original_input
      end
    end
  end

  return nil, original_input
end

---@param item Searchable
---@return boolean
function TodoMatch:match(item)
  local item_todo = item.todo

  if #self.anyOf > 0 then
    for _, todo_value in ipairs(self.anyOf) do
      if item_todo == todo_value then
        return true
      end
    end

    return false
  elseif #self.noneOf > 0 then
    for _, todo_value in ipairs(self.noneOf) do
      if item_todo == todo_value then
        return false
      end
    end

    return true
  else
    return true
  end
end

return Search

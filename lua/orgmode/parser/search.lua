--TODO:
--Support regex search and date search

---@class Search
---@field term string
---@field expressions table
---@field logic SearchLogicClause[]
---@field todo_search table
local Search = {}

---@class SearchLogicClause
---@field contains string[]
---@field excludes string[]

---@class Searchable
---@field props table<string, string>
---@field tags string[]
---@field todo string

---@type table<string, fun(a: string|number, b: string|number): boolean>
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

---@param term string
function Search:new(term)
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
    local passes = self:_check_or(or_item, item)
    if passes then
      return true
    end
  end
  return false
end

---@param or_item SearchLogicClause
---@param item Searchable
---@return boolean
function Search:_check_or(or_item, item)
  for _, val in ipairs(or_item.contains) do
    if not self:_matches(val, item) then
      return false
    end
  end

  for _, val in ipairs(or_item.excludes) do
    if self:_matches(val, item) then
      return false
    end
  end

  if self.todo_search then
    return self.todo_search:check({ tags = item.todo })
  end

  return true
end

---@param val string
---@param item Searchable
---@return boolean
function Search:_matches(val, item)
  local query_prop_name, operator, query_prop_val = val:match('([^=<>]*)([=<>]+)([^=<>]*)')

  -- If its a simple tag search, then just search the tags
  if not query_prop_name then
    -- If no tags are defined, it definitely doesn't match
    if not item.tags then
      return false
    end

    -- If multiple tags are on the item, check each of them against the query
    if type(item.tags) == 'table' then
      return vim.tbl_contains(item.tags, val)
    end

    -- If its just a single tag, check that one
    return val == item.tags
  end

  ---@type string|number
  local prop_name = string.lower(vim.trim(query_prop_name))
  ---@type string|number
  local prop_val = vim.trim(query_prop_val)

  -- If the item doesn't define the property in question, it definitely can't match
  if not item.props or not item.props[query_prop_name] then
    return false
  end

  --- @type string|number
  local item_val = item.props[prop_name]

  -- If the value is a number, parse it as such
  local prop_val_number = tonumber(prop_val)
  if prop_val_number then
    prop_val = prop_val_number
    local item_val_number = tonumber(item_val)
    if not item_val_number then
      return false
    else
      item_val = item_val_number
    end
  end

  -- If the value could not be parsed as another value, strip any leading and trailing quotation mark from it.
  if type(prop_val) == 'string' then
    prop_val = prop_val:gsub('^"', ''):gsub('"$', '')
  end

  -- If the operator is not defined, we can't match this item
  if not OPERATORS[operator] then
    return false
  end

  -- Perform the comparison with the appropriate operator function
  return OPERATORS[operator](item_val, prop_val)
end

---@private
---@return nil
function Search:_parse()
  local term = self.term
  local todo_search = term:match('/([^/]*)$')
  if todo_search then
    self.todo_search = Search:new(todo_search)
    term = term:gsub('/([^/]*)$', '')
  end
  for or_item in vim.gsplit(term, '|', true) do
    local a = {
      contains = {},
      excludes = {},
    }
    for and_item in vim.gsplit(or_item, '&', true) do
      for op, exp in and_item:gmatch('([%+%-]*)([^%-%+]+)') do
        if op == '' or op:match('^%+*$') then
          table.insert(a.contains, exp)
        else
          table.insert(a.excludes, exp)
        end
      end
    end
    table.insert(self.logic, a)
  end
end

return Search

--TODO:
--Support regex search and date search

---@class Search
---@field term string
---@field expressions table
---@field logic table
---@field todo_search table
local Search = {}

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

function Search:check(item)
  for _, or_item in ipairs(self.logic) do
    local passes = self:_check_or(or_item, item)
    if passes then
      return true
    end
  end
  return false
end

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

function Search:_matches(val, item)
  local prop_name, operator, prop_val = val:match('([^=<>]*)([=<>]+)([^=<>]*)')
  if not prop_name then
    if not item.tags then return false end
    if type(item.tags) == 'table' then
      return vim.tbl_contains(item.tags, val)
    end
    return val == item.tags
  end
  prop_name = vim.trim(prop_name)
  prop_val = vim.trim(prop_val)
  if not item.props or not item.props[prop_name] then return false end
  local item_val = item.props[prop_name]

  if tonumber(prop_val) then
    prop_val = tonumber(prop_val)
    item_val = tonumber(item_val)
    if not item_val then return false end
  end

  if type(prop_val) == 'string' then
    prop_val = prop_val:gsub('^"', ''):gsub('"$', '')
  end

  local operators = {
    ['='] = function(a, b) return a == b end,
    ['<='] = function(a, b) return a <= b end,
    ['<'] = function(a, b) return a < b end,
    ['>='] = function(a, b) return a >= b end,
    ['>'] = function(a, b) return a > b end,
    ['<>'] = function(a, b) return a ~= b end,
  }

  if not operators[operator] then return false end

  return operators[operator](item_val, prop_val)
end

---@private
---@return string
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

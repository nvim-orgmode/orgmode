local utils = require('orgmode.utils')
local TodoKeyword = require('orgmode.objects.todo_keywords.todo_keyword')

---@class OrgTodoKeywords
---@field org_todo_keywords string[]
---@field org_todo_keyword_faces table<string, string>
---@field todo_keywords OrgTodoKeyword[]
local TodoKeywords = {}
TodoKeywords.__index = TodoKeywords

---@param opts { org_todo_keywords: string[], org_todo_keyword_faces: table<string, string> }
---@return OrgTodoKeywords
function TodoKeywords:new(opts)
  local this = setmetatable({
    org_todo_keywords = opts.org_todo_keywords,
    org_todo_keyword_faces = opts.org_todo_keyword_faces,
  }, self)
  this:_parse()
  return this
end

---Return a lookup table of all todo keywords by value.
---@return table<string, OrgTodoKeyword>
function TodoKeywords:keys()
  local result = {}
  for _, keyword in ipairs(self.todo_keywords) do
    result[keyword.value] = keyword
  end
  return result
end

---@return boolean
function TodoKeywords:has_fast_access()
  return utils.find(self.todo_keywords, function(todo_keyword)
    return todo_keyword.has_fast_access
  end) and true or false
end

---@param keyword string
---@return OrgTodoKeyword | nil
function TodoKeywords:find(keyword)
  return utils.find(self.todo_keywords, function(todo_keyword)
    return todo_keyword.value == keyword
  end)
end

---@param type OrgTodoKeywordType
---@return OrgTodoKeyword
function TodoKeywords:first_by_type(type)
  for _, keyword in ipairs(self.todo_keywords) do
    if type == keyword.type then
      return keyword
    end
  end
  return self.todo_keywords[#self.todo_keywords]
end

---@return OrgTodoKeyword[]
function TodoKeywords:all()
  return self.todo_keywords
end

---@return OrgTodoKeyword
function TodoKeywords:first()
  return self.todo_keywords[1]
end

---@return OrgTodoKeyword
function TodoKeywords:last()
  return self.todo_keywords[#self.todo_keywords]
end

---@return string[]
function TodoKeywords:all_values()
  return vim.tbl_map(function(todo_keyword)
    return todo_keyword.value
  end, self.todo_keywords)
end

---@private
function TodoKeywords:_parse()
  local todo, done = self:_split_todo_and_done()
  local list = {}
  for i, keyword in ipairs(todo) do
    local todo_keyword = TodoKeyword:new({
      type = 'TODO',
      keyword = keyword,
      index = i,
    })
    todo_keyword.hl = self:_get_hl(todo_keyword.value, 'TODO')
    table.insert(list, todo_keyword)
  end

  for i, keyword in ipairs(done) do
    local todo_keyword = TodoKeyword:new({
      type = 'DONE',
      keyword = keyword,
      index = #todo + i,
    })
    todo_keyword.hl = self:_get_hl(todo_keyword.value, 'DONE')
    table.insert(list, todo_keyword)
  end

  self.todo_keywords = list
end

---@private
---@param keyword string
---@param type OrgTodoKeywordType
---@return string
function TodoKeywords:_get_hl(keyword, type)
  if not self.org_todo_keyword_faces[keyword] then
    return type == 'TODO' and '@org.keyword.todo' or '@org.keyword.done'
  end
  return ('@org.keyword.face.%s'):format(keyword:gsub('%-', ''))
end

---@private
---@return string[], string[]
function TodoKeywords:_split_todo_and_done()
  local keywords = self.org_todo_keywords
  local has_separator = vim.tbl_contains(keywords, '|')
  if not has_separator then
    return { unpack(keywords, 1, #keywords - 1) }, { keywords[#keywords] }
  end

  local type = 'TODO'
  local by_type = {
    TODO = {},
    DONE = {},
  }
  for _, keyword in ipairs(keywords) do
    if keyword == '|' then
      type = 'DONE'
    else
      table.insert(by_type[type], keyword)
    end
  end

  return by_type.TODO, by_type.DONE
end

return TodoKeywords

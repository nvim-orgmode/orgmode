local utils = require('orgmode.utils')
local TodoKeyword = require('orgmode.objects.todo_keywords.todo_keyword')

---@class OrgTodoKeywords
---@field org_todo_keywords string[][]|string[]
---@field org_todo_keyword_faces table<string, string>
---@field todo_keywords OrgTodoKeyword[]
---@field sequences OrgTodoKeyword[][] Array of todo keyword sequences
local TodoKeywords = {}
TodoKeywords.__index = TodoKeywords

---@param opts { org_todo_keywords: string[][]|string[], org_todo_keyword_faces: table<string, string> }
---@return OrgTodoKeywords
function TodoKeywords:new(opts)
  -- Support both single sequence (string[]) and multiple sequences (string[][])
  local normalized_keywords = opts.org_todo_keywords
  if type(normalized_keywords[1]) ~= 'table' then
    normalized_keywords = { normalized_keywords }
  end

  local this = setmetatable({
    org_todo_keywords = normalized_keywords,
    org_todo_keyword_faces = opts.org_todo_keyword_faces,
    sequences = {},
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

---@param keyword string
---@return number | nil sequence index this keyword belongs to
function TodoKeywords:find_sequence_index(keyword)
  for seq_idx, seq in ipairs(self.sequences) do
    for _, todo_keyword in ipairs(seq) do
      if todo_keyword.value == keyword then
        return seq_idx
      end
    end
  end
  return nil
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

---@param sequence_idx? number
---@return OrgTodoKeyword[]
function TodoKeywords:sequence(sequence_idx)
  return self.sequences[sequence_idx or 1] or {}
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
  self.todo_keywords = {}
  self.sequences = {}
  local used_shortcuts = {}

  for seq_idx, sequence in ipairs(self.org_todo_keywords) do
    local keyword_offset = #self.todo_keywords
    local keywords, seq_keywords = self:_parse_sequence(sequence, seq_idx, used_shortcuts, keyword_offset)

    for _, keyword in ipairs(keywords) do
      table.insert(self.todo_keywords, keyword)
    end
    table.insert(self.sequences, seq_keywords)
  end
end

---@private
---@param keyword string
---@param status_type string 'TODO' or 'DONE'
---@param index number
---@param seq_idx number
---@param used_shortcuts table<string, boolean>
---@return OrgTodoKeyword
function TodoKeywords:_create_keyword(keyword, status_type, index, seq_idx, used_shortcuts)
  local todo_keyword = TodoKeyword:new({
    type = status_type,
    keyword = keyword,
    index = index,
    sequence_index = seq_idx,
  })

  if todo_keyword.has_fast_access then
    used_shortcuts[todo_keyword.shortcut] = true
  elseif not used_shortcuts[todo_keyword.shortcut] and #self.org_todo_keywords > 1 then
    -- Enable fast access for all keywords when multiple sequences exist
    todo_keyword.has_fast_access = true
    used_shortcuts[todo_keyword.shortcut] = true
  end

  todo_keyword.hl = self:_get_hl(todo_keyword.value, status_type)
  return todo_keyword
end

---@private
---@param keywords string[]
---@param seq_idx number
---@param used_shortcuts table<string, boolean>
---@param keyword_offset number
---@return OrgTodoKeyword[] keywords for the sequence
---@return OrgTodoKeyword[] seq_keywords keywords in this sequence
function TodoKeywords:_parse_sequence(keywords, seq_idx, used_shortcuts, keyword_offset)
  keyword_offset = keyword_offset or 0
  local todo, done = self:_split_todo_and_done(keywords)
  local list = {}
  local seq_keywords = {}

  for i, keyword in ipairs(todo) do
    local todo_keyword = self:_create_keyword(keyword, 'TODO', keyword_offset + i, seq_idx, used_shortcuts)
    table.insert(list, todo_keyword)
    table.insert(seq_keywords, todo_keyword)
  end

  for i, keyword in ipairs(done) do
    local todo_keyword = self:_create_keyword(keyword, 'DONE', keyword_offset + #todo + i, seq_idx, used_shortcuts)
    table.insert(list, todo_keyword)
    table.insert(seq_keywords, todo_keyword)
  end

  return list, seq_keywords
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
---@param keywords string[]
---@return string[], string[]
function TodoKeywords:_split_todo_and_done(keywords)
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

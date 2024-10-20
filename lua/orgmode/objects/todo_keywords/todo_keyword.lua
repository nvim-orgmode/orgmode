---@alias OrgTodoKeywordType 'TODO' | 'DONE'

---@class OrgTodoKeyword
---@field keyword string
---@field index number
---@field type OrgTodoKeywordType
---@field value string
---@field shortcut string
---@field hl string
---@field has_fast_access boolean
local TodoKeyword = {}
TodoKeyword.__index = TodoKeyword

---@param opts { type: OrgTodoKeywordType, keyword: string, index: number }
---@return OrgTodoKeyword
function TodoKeyword:new(opts)
  local this = setmetatable({
    keyword = opts.keyword,
    type = opts.type,
    index = opts.index,
    has_fast_access = false,
  }, self)
  this:parse()
  return this
end

function TodoKeyword:empty()
  return setmetatable({
    keyword = '',
    value = '',
    type = '',
    index = 1,
    has_fast_access = false,
    hl = '',
  }, self)
end

function TodoKeyword:is_empty()
  return self.keyword == ''
end

function TodoKeyword:parse()
  self.value = self.keyword
  self.shortcut = self.keyword:sub(1, 1):lower()

  local value, shortcut = self.keyword:match('(.*)%((.)[^%)]*%)$')
  if value and shortcut then
    self.value = value
    self.shortcut = shortcut
    self.has_fast_access = true
  end
end

return TodoKeyword

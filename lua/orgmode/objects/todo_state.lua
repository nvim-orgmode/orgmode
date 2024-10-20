local config = require('orgmode.config')
local utils = require('orgmode.utils')
local TodoKeyword = require('orgmode.objects.todo_keywords.todo_keyword')

---@class OrgTodoState
---@field current_state OrgTodoKeyword | nil
---@field todos OrgTodoKeywords
local TodoState = {}

---@param data { current_state: string | nil }
---@return OrgTodoState
function TodoState:new(data)
  local opts = {}
  opts.todos = config:get_todo_keywords()
  opts.current_state = data.current_state and opts.todos:find(data.current_state) or TodoKeyword:empty()
  setmetatable(opts, self)
  self.__index = self
  return opts
end

---@return boolean
function TodoState:has_fast_access()
  return self.todos:has_fast_access()
end

---@return OrgTodoKeyword | nil
function TodoState:open_fast_access()
  local output = {}
  for _, todo in ipairs(self.todos:all()) do
    table.insert(output, { '[' })
    table.insert(output, { todo.shortcut, 'Title' })
    table.insert(output, { ']' })
    table.insert(output, { ' ' })
    table.insert(output, { todo.value, todo.hl })
    table.insert(output, { '  ' })
  end

  table.insert(output, { '\n' })
  vim.api.nvim_echo(output, true, {})

  local raw = vim.fn.nr2char(vim.fn.getchar())
  local char = string.lower(raw)
  vim.cmd('redraw!')

  if char == ' ' then
    return TodoKeyword:empty()
  end

  for _, todo in ipairs(self.todos:all()) do
    if todo.shortcut == char then
      return todo
    end
  end
end

---@return OrgTodoKeyword | nil
function TodoState:get_next()
  return self:_get_direction(1)
end

---@return OrgTodoKeyword | nil
function TodoState:get_prev()
  return self:_get_direction(-1)
end

---@private
---@param direction 1 | -1
---@return OrgTodoKeyword | nil
function TodoState:_get_direction(direction)
  if self.current_state:is_empty() then
    local keyword = direction == 1 and self.todos:first() or self.todos:last()
    self.current_state = keyword
    return keyword
  end

  local next_state = self.todos:all()[self.current_state.index + direction]
  if not next_state then
    self.current_state = TodoKeyword:empty()
    return self.current_state
  end
  self.current_state = next_state
  return next_state
end

---@param headline OrgHeadline|nil
---@return OrgTodoKeyword
function TodoState:get_reset_todo(headline)
  local repeat_to_state = (headline and headline:get_property('REPEAT_TO_STATE'))
    or config.opts.org_todo_repeat_to_state
  local todo_keyword = self.todos:find(repeat_to_state)

  if todo_keyword then
    return todo_keyword
  end

  return self.todos:first()
end

return TodoState

local config = require('orgmode.config')

---@class TodoState
---@field current_state string
---@field todos table
local TodoState = {}

---@param data table
function TodoState:new(data)
  local opts = {}
  opts.current_state = data.current_state or ''
  local todo_keywords = config:get_todo_keywords()
  opts.todos = {
    TODO = vim.tbl_add_reverse_lookup(todo_keywords.TODO),
    DONE = vim.tbl_add_reverse_lookup(todo_keywords.DONE),
    ALL = vim.tbl_add_reverse_lookup(todo_keywords.ALL)
  }
  setmetatable(opts, self)
  self.__index = self
  return opts
end

---@return table
function TodoState:get_next()
  if self.current_state == '' then
    self.current_state = self.todos.ALL[1]
    return { value = self.todos.ALL[1], type = 'TODO' }
  end
  local current_item_index = self.todos.ALL[self.current_state]
  local next_state = self.todos.ALL[current_item_index + 1]
  if not next_state then
    self.current_state = ''
    return { value = '', type = '' }
  end
  self.current_state = next_state
  local type = self.todos.TODO[next_state] and 'TODO' or 'DONE'

  return { value = next_state,  type = type }
end

---@return table
function TodoState:get_prev()
  if self.current_state == '' then
    local last_item = self.todos.ALL[#self.todos.ALL]
    self.current_state = last_item
    return { value = last_item, type = 'DONE' }
  end
  local current_item_index = self.todos.ALL[self.current_state]
  local prev_state = self.todos.ALL[current_item_index - 1]
  if not prev_state then
    self.current_state = ''
    return { value = '', type = '' }
  end
  self.current_state = prev_state
  local type = self.todos.TODO[prev_state] and 'TODO' or 'DONE'

  return { value = prev_state,  type = type }
end

function TodoState:get_todo()
  return { value = self.todos.TODO[1], type = 'TODO' }
end

return TodoState

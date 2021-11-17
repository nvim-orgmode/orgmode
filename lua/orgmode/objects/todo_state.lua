local config = require('orgmode.config')
local highlights = require('orgmode.colors.highlights')
local utils = require('orgmode.utils')

---@class TodoState
---@field current_state string
---@field hl_map table
---@field todos table
local TodoState = {}

---@param data table
function TodoState:new(data)
  local opts = {}
  opts.current_state = data.current_state or ''
  local todo_keywords = config:get_todo_keywords()
  opts.todos = {
    TODO = vim.tbl_add_reverse_lookup({ unpack(todo_keywords.TODO) }),
    DONE = vim.tbl_add_reverse_lookup({ unpack(todo_keywords.DONE) }),
    ALL = vim.tbl_add_reverse_lookup({ unpack(todo_keywords.ALL) }),
    FAST_ACCESS = todo_keywords.FAST_ACCESS,
    has_fast_access = todo_keywords.has_fast_access,
  }
  opts.hl_map = highlights.get_agenda_hl_map()
  setmetatable(opts, self)
  self.__index = self
  return opts
end

---@return boolean
function TodoState:has_fast_access()
  return self.todos.has_fast_access
end

function TodoState:open_fast_access()
  local enumerated = {}

  for _, todo in ipairs(self.todos.FAST_ACCESS) do
    table.insert(enumerated, {
      choice_value = todo.shortcut,
      choice_text = todo.shortcut,
      choice_hl = 'Title',
      desc_text = todo.value,
      desc_hl = self.hl_map[todo.value] or self.hl_map[todo.type],
      ctx = todo,
    })
  end

  local choice = utils.choose(enumerated)
  if not choice then
    return
  end

  return {
    value = choice.ctx.value,
    type = choice.ctx.type,
    hl = self.hl_map[choice.choice_value] or self.hl_map[choice.ctx.type],
  }
end

---@return table
function TodoState:get_next()
  if self.current_state == '' then
    self.current_state = self.todos.ALL[1]
    local val = self.todos.ALL[1]
    return { value = val, type = 'TODO', hl = self.hl_map[val] or self.hl_map.TODO }
  end
  local current_item_index = self.todos.ALL[self.current_state]
  local next_state = self.todos.ALL[current_item_index + 1]
  if not next_state then
    self.current_state = ''
    return { value = '', type = '' }
  end
  self.current_state = next_state
  local type = self.todos.TODO[next_state] and 'TODO' or 'DONE'

  return { value = next_state, type = type, hl = self.hl_map[next_state] or self.hl_map[type] }
end

---@return table
function TodoState:get_prev()
  if self.current_state == '' then
    local last_item = self.todos.ALL[#self.todos.ALL]
    self.current_state = last_item
    return { value = last_item, type = 'DONE', hl = self.hl_map[last_item] or self.hl_map.DONE }
  end
  local current_item_index = self.todos.ALL[self.current_state]
  local prev_state = self.todos.ALL[current_item_index - 1]
  if not prev_state then
    self.current_state = ''
    return { value = '', type = '' }
  end
  self.current_state = prev_state
  local type = self.todos.TODO[prev_state] and 'TODO' or 'DONE'

  return { value = prev_state, type = type, hl = self.hl_map[prev_state] or self.hl_map[type] }
end

function TodoState:get_todo()
  local first = self.todos.TODO[1]
  return { value = first, type = 'TODO', hl = self.hl_map[first] or self.hl_map.TODO }
end

return TodoState

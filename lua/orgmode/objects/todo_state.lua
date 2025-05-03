local config = require('orgmode.config')
local TodoKeyword = require('orgmode.objects.todo_keywords.todo_keyword')

---@class OrgTodoState
---@field current_state OrgTodoKeyword | nil
---@field todos OrgTodoKeywords
local TodoState = {}

---@param data { current_state: string | OrgTodoKeyword | nil, todos: table | nil }
---@return OrgTodoState
function TodoState:new(data)
  local opts = {}
  opts.todos = data.todos or config:get_todo_keywords()

  -- Assign it locally to make the type checker happy.
  local current_state = data.current_state

  if current_state then
    -- Find the keyword by string value
    if type(current_state) == 'string' then
      opts.current_state = opts.todos:find(current_state) or TodoKeyword:empty()
    -- Direct assignment of a TodoKeyword
    elseif type(current_state) == 'table' and current_state.value then
      opts.current_state = current_state
    else
      opts.current_state = TodoKeyword:empty()
    end
  else
    opts.current_state = TodoKeyword:empty()
  end

  setmetatable(opts, self)
  self.__index = self
  return opts
end

---@return boolean
function TodoState:has_fast_access()
  -- Enable fast access mode if:
  -- 1. There are multiple sequences defined, OR
  -- 2. At least one keyword has an explicit shortcut defined
  if #self.todos.sequences > 1 or self.todos:has_fast_access() then
    return true
  end
  return false
end

---@return OrgTodoKeyword | nil
function TodoState:open_fast_access()
  local output = {}

  -- Group keywords by sequence
  local sequences = {}
  for seq_idx = 1, #self.todos.sequences do
    sequences[seq_idx] = {}
  end

  -- Add each keyword to its respective sequence group
  for _, todo in ipairs(self.todos:all()) do
    local seq_idx = todo.sequence_index
    if not sequences[seq_idx] then
      sequences[seq_idx] = {}
    end

    local entry = {}
    table.insert(entry, { '[' })
    table.insert(entry, { todo.shortcut, 'Title' })
    table.insert(entry, { ']' })
    table.insert(entry, { ' ' })
    table.insert(entry, { todo.value, todo.hl })
    table.insert(entry, { '  ' })

    table.insert(sequences[seq_idx], entry)
  end

  -- Display each sequence on a separate line
  for seq_idx, seq_entries in ipairs(sequences) do
    -- Flatten the sequence entries
    for _, entry in ipairs(seq_entries) do
      for _, part in ipairs(entry) do
        table.insert(output, part)
      end
    end

    -- Add a newline after each sequence (except the last one)
    table.insert(output, { '\n' })
  end

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
---@param direction number 1 for next, -1 for previous
---@return OrgTodoKeyword | nil
function TodoState:_get_direction(direction)
  -- When starting from an empty state, get the first/last keyword
  if self.current_state:is_empty() then
    return self:_handle_empty_state_navigation(direction)
  end

  -- Get the keyword sequence this state belongs to
  return self:_navigate_within_sequence(direction)
end

---@private
---@param direction number 1 for next, -1 for previous
---@return OrgTodoKeyword
function TodoState:_handle_empty_state_navigation(direction)
  -- When we're starting from an empty state and moving forward,
  -- go to the first todo keyword of the first sequence
  if direction == 1 then
    local keyword = self.todos:first()
    self.current_state = keyword
    return keyword
  -- When we're starting from an empty state and moving backward,
  -- go to the last todo keyword of the last sequence
  else
    local keyword = self.todos:last()
    self.current_state = keyword
    return keyword
  end
end

---@private
---@param direction number 1 for next, -1 for previous
---@return OrgTodoKeyword
function TodoState:_navigate_within_sequence(direction)
  -- Get the sequence this keyword belongs to
  local sequence_idx = self.current_state.sequence_index
  local seq_keywords = self.todos:sequence(sequence_idx)

  -- Find the position of the current keyword in its sequence
  local current_idx = nil
  for idx, keyword in ipairs(seq_keywords) do
    if keyword.value == self.current_state.value then
      current_idx = idx
      break
    end
  end

  if not current_idx then
    -- Fallback to the default behavior if we can't find the keyword in its sequence
    local next_state = self.todos:all()[self.current_state.index + direction]
    if not next_state then
      self.current_state = TodoKeyword:empty()
      return self.current_state
    end
    self.current_state = next_state
    return next_state
  end

  -- Get the next keyword in the sequence or cycle to empty
  local next_idx = current_idx + direction
  if next_idx < 1 or next_idx > #seq_keywords then
    -- If we go beyond sequence boundaries, cycle to empty state
    self.current_state = TodoKeyword:empty()
    return self.current_state
  end

  self.current_state = seq_keywords[next_idx]
  return self.current_state
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

  -- If the headline has a current state, use first todo keyword from the same sequence
  if headline and self.current_state and not self.current_state:is_empty() then
    local seq_idx = self.current_state.sequence_index
    local seq = self.todos:sequence(seq_idx)
    for _, keyword in ipairs(seq) do
      if keyword.type == 'TODO' then
        return keyword
      end
    end
  end

  -- Default fallback to the first todo keyword
  return self.todos:first()
end

return TodoState

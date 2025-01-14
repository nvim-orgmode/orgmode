local utils = require('orgmode.utils')
---@alias OrgAgendaSortingStrategy
---| 'time-up'
---| 'time-down'
---| 'priority-down'
---| 'priority-up'
---| 'tag-up'
---| 'tag-down'
---| 'todo-state-up'
---| 'todo-state-down'
---| 'clocked-up'
---| 'clocked-down'
---| 'category-up'
---| 'category-down'
---| 'category-keep'
local SortingStrategy = {}

---@class SortableEntry
---@field date OrgDate Available only in agenda view
---@field headline OrgHeadline
---@field index number Index of the entry in the fetched list
---@field is_day_match? boolean Is this entry a match for the given day. Available only in agenda view

---@param a SortableEntry
---@param b SortableEntry
function SortingStrategy.time_up(a, b)
  if a.is_day_match and b.is_day_match then
    if a.date:has_time() and b.date:has_time() then
      if a.date.timestamp ~= b.date.timestamp then
        return a.date.timestamp < b.date.timestamp
      end
      return
    end
  end
  if a.is_day_match and a.date:has_time() then
    return true
  end

  if b.is_day_match and b.date:has_time() then
    return false
  end
end

---@param a SortableEntry
---@param b SortableEntry
function SortingStrategy.time_down(a, b)
  local time_up = SortingStrategy.time_up(a, b)
  if type(time_up) == 'boolean' then
    return not time_up
  end
end

---@param a SortableEntry
---@param b SortableEntry
function SortingStrategy.priority_down(a, b)
  if a.headline:get_priority_sort_value() ~= b.headline:get_priority_sort_value() then
    return a.headline:get_priority_sort_value() > b.headline:get_priority_sort_value()
  end
  if a.date and b.date then
    local is_same = a.date:is_same(b.date)
    if not is_same then
      return a.date:is_before(b.date)
    end
    if a.date.type ~= b.date.type then
      return a.date:get_type_sort_value() < b.date:get_type_sort_value()
    end
  end
end

function SortingStrategy.priority_up(a, b)
  local priority_down = SortingStrategy.priority_down(a, b)
  if type(priority_down) == 'boolean' then
    return not priority_down
  end
end

---@param a SortableEntry
---@param b SortableEntry
function SortingStrategy.tag_up(a, b)
  local a_tags = a.headline:tags_to_string(true)
  local b_tags = b.headline:tags_to_string(true)
  if a_tags == '' and b_tags == '' then
    return
  end
  if a_tags == b_tags then
    return
  end
  if a_tags == '' then
    return false
  end
  if b_tags == '' then
    return true
  end
  return a_tags < b_tags
end

---@param a SortableEntry
---@param b SortableEntry
function SortingStrategy.tag_down(a, b)
  local tag_up = SortingStrategy.tag_up(a, b)
  if type(tag_up) == 'boolean' then
    return not tag_up
  end
end

---@param a SortableEntry
---@param b SortableEntry
function SortingStrategy.todo_state_up(a, b)
  local _, _, _, a_index = a.headline:get_todo()
  local _, _, _, b_index = b.headline:get_todo()
  if a_index and b_index then
    if a_index ~= b_index then
      return a_index < b_index
    end
    return nil
  end
  if a_index then
    return true
  end
  if b_index then
    return false
  end
end

---@param a SortableEntry
---@param b SortableEntry
function SortingStrategy.todo_state_down(a, b)
  local todo_state_up = SortingStrategy.todo_state_up(a, b)
  if type(todo_state_up) == 'boolean' then
    return not todo_state_up
  end
end

---@param a SortableEntry
---@param b SortableEntry
function SortingStrategy.category_up(a, b)
  if a.headline.file:get_category() ~= b.headline.file:get_category() then
    return a.headline.file:get_category() < b.headline.file:get_category()
  end
end

---@param a SortableEntry
---@param b SortableEntry
function SortingStrategy.category_down(a, b)
  local category_up = SortingStrategy.category_up(a, b)
  if type(category_up) == 'boolean' then
    return not category_up
  end
end

---@param a SortableEntry
---@param b SortableEntry
function SortingStrategy.category_keep(a, b)
  if a.headline.file.index ~= b.headline.file.index then
    return a.headline.file.index < b.headline.file.index
  end
end

---@param a SortableEntry
---@param b SortableEntry
function SortingStrategy.clocked_up(a, b)
  if a.headline:is_clocked_in() and not b.headline:is_clocked_in() then
    return true
  end
  if not a.headline:is_clocked_in() and b.headline:is_clocked_in() then
    return false
  end
end

---@param a SortableEntry
---@param b SortableEntry
function SortingStrategy.clocked_down(a, b)
  local clocked_up = SortingStrategy.clocked_up(a, b)
  if type(clocked_up) == 'boolean' then
    return not clocked_up
  end
end

---@param a SortableEntry
---@param b SortableEntry
local fallback_sort = function(a, b)
  if a.headline.file.index ~= b.headline.file.index then
    return a.headline.file.index < b.headline.file.index
  end

  return a.index < b.index
end

---@generic T
---@param items T[]
---@param strategies OrgAgendaSortingStrategy[]
---@param make_entry fun(item: T): SortableEntry
local function sort(items, strategies, make_entry)
  table.sort(items, function(a, b)
    local entry_a = make_entry(a)
    local entry_b = make_entry(b)

    for _, fn in ipairs(strategies) do
      local sorting_fn = SortingStrategy[fn:gsub('-', '_')]
      if not sorting_fn then
        utils.echo_error('Unknown sorting strategy: ' .. fn)
        break
      end
      local result = sorting_fn(entry_a, entry_b)
      if result ~= nil then
        return result
      end
    end

    return fallback_sort(entry_a, entry_b)
  end)

  return items
end

return {
  sort = sort,
}

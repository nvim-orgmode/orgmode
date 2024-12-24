local AgendaFilter = require('orgmode.agenda.filter')
local Range = require('orgmode.files.elements.range')
local utils = require('orgmode.utils')
local agenda_highlights = require('orgmode.colors.highlights')
local hl_map = agenda_highlights.get_agenda_hl_map()

local function sort_todos(todos)
  table.sort(todos, function(a, b)
    -- Tasks marked as clocked_in appear first
    if a:is_clocked_in() then
      return true
    end
    if b:is_clocked_in() then
      return false
    end

    -- Then tasks are sorted by their priority
    if a:get_priority_sort_value() ~= b:get_priority_sort_value() then
      return a:get_priority_sort_value() > b:get_priority_sort_value()
    end

    -- Then tasks are sorted by their TODO keyword
    local a_keyword = a:get_todo()
    local b_keyword = b:get_todo()
    if (a_keyword and b_keyword) and (a_keyword ~= b_keyword) then
      return a:get_todo_sort_value() < b:get_todo_sort_value()
    end

    -- Then tasks which have a DEADLINE have priority over SCHEDULED over nothing
    local a_deadline = a:get_deadline_date()
    local a_scheduled = a:get_scheduled_date()
    local b_deadline = b:get_deadline_date()
    local b_scheduled = b:get_scheduled_date()

    -- If both have deadlines, earlier deadline comes first
    if a_deadline and b_deadline then
      return a_deadline < b_deadline
    end

    -- If only one has deadline, it comes first
    if a_deadline then
      return true
    end
    if b_deadline then
      return false
    end

    -- If both have scheduled dates, earlier date comes first
    if a_scheduled and b_scheduled then
      return a_scheduled < b_scheduled
    end

    -- If only one has scheduled date, it comes first
    if a_scheduled then
      return true
    end
    if b_scheduled then
      return false
    end

    -- Then tasks are sorted by their category keyword
    return a:get_category() < b:get_category()
  end)
  return todos
end

---@class OrgAgendaTodosView
---@field items table[]
---@field content table[]
---@field highlights table[]
---@field header string
---@field search string
---@field filters OrgAgendaFilter
---@field files OrgFiles
local AgendaTodosView = {}

function AgendaTodosView:new(opts)
  opts = opts or {}
  local data = {
    content = {},
    highlights = {},
    items = {},
    search = opts.search or '',
    filters = opts.filters or AgendaFilter:new(),
    header = opts.org_agenda_overriding_header,
    files = opts.files,
  }

  setmetatable(data, self)
  self.__index = self
  return data
end

function AgendaTodosView:build()
  self.items = {}
  for _, orgfile in ipairs(self.files:all()) do
    for _, headline in ipairs(orgfile:get_unfinished_todo_entries()) do
      if self.filters:matches(headline) then
        table.insert(self.items, headline)
      end
    end
  end

  self.content = { { line_content = 'Global list of TODO items of type: ALL' } }
  self.highlights = {}
  self.active_view = 'todos'
  self.generate_view(self.items, self.content, self.filters)
  return self
end

function AgendaTodosView.generate_view(items, content, filters)
  items = sort_todos(items)
  local offset = #content
  local longest_category = utils.reduce(items, function(acc, todo)
    return math.max(acc, vim.api.nvim_strwidth(todo:get_category()))
  end, 0) or 0

  for i, headline in ipairs(items) do
    if filters:matches(headline) then
      table.insert(content, AgendaTodosView.generate_todo_item(headline, longest_category, i + offset))
    end
  end

  return { items = items, content = content }
end

---@param headline OrgHeadline
---@param longest_category number
---@param line_nr number
function AgendaTodosView.generate_todo_item(headline, longest_category, line_nr)
  local category = '  ' .. utils.pad_right(string.format('%s:', headline:get_category()), longest_category + 1)
  local todo_keyword, _, todo_type = headline:get_todo()
  todo_keyword = todo_keyword or ''
  local todo_keyword_padding = todo_keyword ~= '' and ' ' or ''
  local title_with_priority = headline:get_title_with_priority()
  local todo_keyword_len = todo_keyword:len()
  local line = string.format('  %s%s%s %s', category, todo_keyword_padding, todo_keyword, title_with_priority)
  if #headline:get_tags() > 0 then
    local tags_string = headline:tags_to_string()
    local padding_length =
      math.max(1, utils.winwidth() - vim.api.nvim_strwidth(line) - vim.api.nvim_strwidth(tags_string))
    local indent = string.rep(' ', padding_length)
    line = string.format('%s%s%s', line, indent, tags_string)
  end
  local todo_keyword_pos = category:len() + 4
  local highlights = {}
  if todo_keyword ~= '' then
    table.insert(highlights, {
      hlgroup = hl_map[todo_keyword] or hl_map[todo_type],
      range = Range:new({
        start_line = line_nr,
        end_line = line_nr,
        start_col = todo_keyword_pos,
        end_col = todo_keyword_pos + todo_keyword_len,
      }),
    })
  end
  local priority = headline:get_priority()
  if priority and hl_map.priority[priority] then
    local col_start = todo_keyword_pos + (todo_keyword_len > 0 and todo_keyword_len + 1 or 0)
    table.insert(highlights, {
      hlgroup = hl_map.priority[priority].hl_group,
      range = Range:new({
        start_line = line_nr,
        end_line = line_nr,
        start_col = col_start,
        end_col = col_start + 4,
      }),
    })
  end
  if headline:is_clocked_in() then
    table.insert(highlights, {
      range = Range:new({
        start_line = line_nr,
        end_line = line_nr,
        start_col = 1,
        end_col = 0,
      }),
      hlgroup = 'Visual',
      whole_line = true,
    })
  end
  return {
    line_content = line,
    longest_category = longest_category,
    line = line_nr,
    jumpable = true,
    file = headline.file.filename,
    file_position = headline:get_range().start_line,
    headline = headline,
    highlights = highlights,
  }
end

return AgendaTodosView

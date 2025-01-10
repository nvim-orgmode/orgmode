local AgendaView = require('orgmode.agenda.view.init')
local AgendaLine = require('orgmode.agenda.view.line')
local AgendaFilter = require('orgmode.agenda.filter')
local AgendaLineToken = require('orgmode.agenda.view.token')
local utils = require('orgmode.utils')
local agenda_highlights = require('orgmode.colors.highlights')
local hl_map = agenda_highlights.get_agenda_hl_map()

---@class OrgAgendaTodosTypeOpts
---@field files OrgFiles
---@field agenda_filter OrgAgendaFilter
---@field filter? string
---@field header? string
---@field subheader? string
---@field todo_only? boolean
---@field is_custom? boolean

---@class OrgAgendaTodosType:OrgAgendaViewType
---@field files OrgFiles
---@field agenda_filter OrgAgendaFilter
---@field filter? OrgAgendaFilter
---@field header? string
---@field subheader? string
---@field bufnr? number
---@field todo_only? boolean
---@field is_custom? boolean
local OrgAgendaTodosType = {}
OrgAgendaTodosType.__index = OrgAgendaTodosType

---@param opts OrgAgendaTodosTypeOpts
function OrgAgendaTodosType:new(opts)
  return setmetatable({
    files = opts.files,
    agenda_filter = opts.agenda_filter,
    filter = opts.filter and AgendaFilter:new():parse(opts.filter, true) or nil,
    header = opts.header,
    subheader = opts.subheader,
    todo_only = opts.todo_only == nil and true or opts.todo_only,
    is_custom = opts.is_custom or false,
  }, OrgAgendaTodosType)
end

---@param bufnr? number
function OrgAgendaTodosType:render(bufnr)
  self.bufnr = bufnr or 0
  local headlines, category_length = self:_get_headlines()
  local agendaView = AgendaView:new({ bufnr = self.bufnr })

  agendaView:add_line(AgendaLine:single_token({
    content = self.header or 'Global list of TODO items of type: ALL',
    hl_group = '@org.agenda.header',
  }))
  agendaView:add_line(AgendaLine:single_token({
    content = self.subheader or '',
    hl_group = '@org.agenda.header',
  }))

  for _, headline in ipairs(headlines) do
    agendaView:add_line(self:_build_line(headline, { category_length = category_length }))
  end

  local result = agendaView:render()
  self.view = result
  return result
end

---@private
---@param headline OrgHeadline
---@param metadata table<string, any>
---@return OrgAgendaLine
function OrgAgendaTodosType:_build_line(headline, metadata)
  local line = AgendaLine:new({
    headline = headline,
    line_hl_group = headline:is_clocked_in() and 'Visual' or nil,
    metadata = metadata,
  })
  line:add_token(AgendaLineToken:new({
    content = '  ' .. utils.pad_right(('%s:'):format(headline:get_category()), metadata.category_length),
  }))

  local todo, _, todo_type = headline:get_todo()
  if todo then
    line:add_token(AgendaLineToken:new({
      content = todo,
      hl_group = hl_map[todo] or hl_map[todo_type],
    }))
  end
  local priority = headline:get_priority()
  if priority ~= '' then
    line:add_token(AgendaLineToken:new({
      content = ('[#%s]'):format(tostring(priority)),
      hl_group = hl_map.priority[priority].hl_group,
    }))
  end
  line:add_token(AgendaLineToken:new({
    content = headline:get_title(),
  }))
  if #headline:get_tags() > 0 then
    local tags_string = headline:tags_to_string()
    line:add_token(AgendaLineToken:new({
      content = tags_string,
      virt_text_pos = 'right_align',
      hl_group = '@org.agenda.tag',
    }))
  end
  return line
end

---@return OrgAgendaLine[]
function OrgAgendaTodosType:get_lines()
  return self.view.lines
end

---@param row number
---@return OrgAgendaLine | nil
function OrgAgendaTodosType:get_line(row)
  return utils.find(self.view.lines, function(line)
    return line.line_nr == row
  end)
end

---@param agenda_line OrgAgendaLine
---@param headline OrgHeadline
function OrgAgendaTodosType:rerender_agenda_line(agenda_line, headline)
  local line = self:_build_line(headline, agenda_line.metadata)
  self.view:replace_line(agenda_line, line)
end

---@param file OrgFile
---@return OrgHeadline[]
function OrgAgendaTodosType:get_file_headlines(file)
  if self.todo_only then
    return file:get_unfinished_todo_entries()
  end

  return file:get_headlines()
end

---@return OrgHeadline[], number
function OrgAgendaTodosType:_get_headlines()
  local items = {}
  local category_length = 0

  for _, orgfile in ipairs(self.files:all()) do
    local headlines = self:get_file_headlines(orgfile)
    for _, headline in ipairs(headlines) do
      if self.agenda_filter:matches(headline) and (not self.filter or self.filter:matches(headline)) then
        category_length = math.max(category_length, vim.api.nvim_strwidth(headline:get_category()))
        table.insert(items, headline)
      end
    end
  end

  self:_sort(items)
  return items, category_length + 1
end

---@private
---@param todos OrgHeadline[]
---@return OrgHeadline[]
function OrgAgendaTodosType:_sort(todos)
  table.sort(todos, function(a, b)
    if a:get_priority_sort_value() ~= b:get_priority_sort_value() then
      return a:get_priority_sort_value() > b:get_priority_sort_value()
    end
    return a:get_category() < b:get_category()
  end)
  return todos
end

return OrgAgendaTodosType

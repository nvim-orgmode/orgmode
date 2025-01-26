local config = require('orgmode.config')
local AgendaView = require('orgmode.agenda.view.init')
local Files = require('orgmode.files')
local AgendaLine = require('orgmode.agenda.view.line')
local AgendaFilter = require('orgmode.agenda.filter')
local AgendaLineToken = require('orgmode.agenda.view.token')
local utils = require('orgmode.utils')
local agenda_highlights = require('orgmode.colors.highlights')
local hl_map = agenda_highlights.get_agenda_hl_map()
local SortingStrategy = require('orgmode.agenda.sorting_strategy')
local Promise = require('orgmode.utils.promise')

---@class OrgAgendaTodosTypeOpts
---@field files OrgFiles
---@field highlighter OrgHighlighter
---@field agenda_filter OrgAgendaFilter
---@field filter? string
---@field tag_filter? string
---@field category_filter? string
---@field agenda_files string | string[] | nil
---@field header? string
---@field subheader? string
---@field todo_only? boolean
---@field sorting_strategy? OrgAgendaSortingStrategy[]
---@field remove_tags? boolean
---@field id? string

---@class OrgAgendaTodosType:OrgAgendaViewType
---@field files OrgFiles
---@field highlighter OrgHighlighter
---@field agenda_filter OrgAgendaFilter
---@field filter? OrgAgendaFilter
---@field tag_filter? string
---@field category_filter? string
---@field agenda_files string | string[] | nil
---@field header? string
---@field subheader? string
---@field bufnr? number
---@field todo_only? boolean
---@field sorting_strategy? OrgAgendaSortingStrategy[]
---@field remove_tags? boolean
---@field valid_filters OrgAgendaFilter[]
---@field id? string
local OrgAgendaTodosType = {}
OrgAgendaTodosType.__index = OrgAgendaTodosType

---@param opts OrgAgendaTodosTypeOpts
function OrgAgendaTodosType:new(opts)
  local this = setmetatable({
    files = opts.files,
    highlighter = opts.highlighter,
    agenda_filter = opts.agenda_filter,
    filter = opts.filter and AgendaFilter:new():parse(opts.filter, true) or nil,
    tag_filter = opts.tag_filter and AgendaFilter:new({ types = { 'tags' } }):parse(opts.tag_filter, true) or nil,
    category_filter = opts.category_filter and AgendaFilter:new({ types = { 'categories' } })
      :parse(opts.category_filter, true) or nil,
    header = opts.header,
    subheader = opts.subheader,
    agenda_files = opts.agenda_files,
    todo_only = opts.todo_only == nil and true or opts.todo_only,
    sorting_strategy = opts.sorting_strategy or vim.tbl_get(config.org_agenda_sorting_strategy, 'todo') or {},
    id = opts.id,
    remove_tags = type(opts.remove_tags) == 'boolean' and opts.remove_tags or config.org_agenda_remove_tags,
  }, OrgAgendaTodosType)
  this.valid_filters = vim.tbl_filter(function(filter)
    return filter and true or false
  end, {
    this.filter,
    this.tag_filter,
    this.category_filter,
    this.agenda_filter,
  })

  this:_setup_agenda_files()
  return this
end

function OrgAgendaTodosType:prepare()
  return Promise.resolve(self)
end

function OrgAgendaTodosType:_setup_agenda_files()
  if not self.agenda_files then
    return
  end
  self.files = Files:new({
    paths = self.agenda_files,
    cache = true,
  }):load_sync(true)
end

function OrgAgendaTodosType:redo()
  if self.agenda_files then
    self.files:load_sync(true)
  end
end

function OrgAgendaTodosType:_get_header()
  if self.header then
    return self.header
  end
  return 'Global list of TODO items of type: ALL'
end

---@param bufnr? number
function OrgAgendaTodosType:render(bufnr)
  self.bufnr = bufnr or 0
  local headlines, category_length = self:_get_headlines()
  local agendaView = AgendaView:new({ bufnr = self.bufnr, highlighter = self.highlighter })

  agendaView:add_line(AgendaLine:single_token({
    content = self:_get_header(),
    hl_group = '@org.agenda.header',
  }))
  if self.subheader then
    agendaView:add_line(AgendaLine:single_token({
      content = self.subheader,
      hl_group = '@org.agenda.header',
    }))
  end

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
    add_markup_to_headline = headline,
  }))
  if not self.remove_tags and #headline:get_tags() > 0 then
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
    for i, headline in ipairs(headlines) do
      if self:_matches_filters(headline) then
        category_length = math.max(category_length, vim.api.nvim_strwidth(headline:get_category()))
        ---@diagnostic disable-next-line: inject-field
        headline.index = i
        table.insert(items, headline)
      end
    end
  end

  self:_sort(items)
  return items, category_length + 1
end

function OrgAgendaTodosType:_matches_filters(headline)
  for _, filter in ipairs(self.valid_filters) do
    if filter and not filter:matches(headline) then
      return false
    end
  end
  return true
end

---@private
---@param todos OrgHeadline[]
---@return OrgHeadline[]
function OrgAgendaTodosType:_sort(todos)
  ---@param headline OrgHeadline
  local make_entry = function(headline)
    return {
      headline = headline,
      index = headline.index,
      is_day_match = false,
    }
  end
  return SortingStrategy.sort(todos, self.sorting_strategy, make_entry)
end

return OrgAgendaTodosType

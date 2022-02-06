local Range = require('orgmode.parser.range')
local Duration = require('orgmode.objects.duration')
local Section = require('orgmode.parser.section')
local LanguageTree = require('vim.treesitter.languagetree')
local config = require('orgmode.config')
local utils = require('orgmode.utils')

---@class File
---@field tree table
---@field file_content string[]
---@field file_content_str string
---@field category string
---@field filename string
---@field changedtick number
---@field sections Section[]
---@field sections_by_line table<number, Section>
---@field source_code_filetypes string[]
---@field is_archive_file boolean
---@field clocked_headline Section
---@field tags string[]
local File = {}

function File:new(tree, file_content, file_content_str, category, filename, is_archive_file)
  local data = {
    tree = tree,
    file_content = file_content,
    file_content_str = file_content_str,
    category = category,
    filename = filename,
    changedtick = 0,
    sections = {},
    sections_by_line = {},
    source_code_filetypes = {},
    is_archive_file = is_archive_file or false,
    tags = {},
    clocked_headline = nil,
  }
  setmetatable(data, self)
  self.__index = self
  data:_parse()
  return data
end

function File:_parse()
  self:_parse_source_code_filetypes()
  self:_parse_directives()
  self:_parse_sections()
end

function File:get_errors()
  if not self:has_errors() then
    return nil
  end

  return self:get_ts_matches('(ERROR) @err')
end

---@return boolean
function File:has_errors()
  return self.tree:root():has_error()
end

function File:convert_to_file_node(node)
  local text = self:get_node_text(node)
  local stars = text:match('^%*+')
  return {
    node = node,
    type = node:type(),
    text = text,
    range = Range.from_node(node),
    level = stars and stars:len() or 0,
  }
end

function File:get_current_node()
  local node = self:get_node_at_cursor()
  return self:convert_to_file_node(node)
end

function File:get_opened_headlines()
  if self.is_archive_file then
    return {}
  end

  local headlines = vim.tbl_filter(function(item)
    return not item:is_archived()
  end, self.sections)

  return headlines
end

---@return Section[]
function File:get_unfinished_todo_entries()
  if self.is_archive_file then
    return {}
  end

  return vim.tbl_filter(function(section)
    return not section:is_archived() and section:is_todo()
  end, self.sections)
end

---@param node table
---@return string
function File:get_node_text(node)
  return utils.get_node_text(node, self.file_content)[1] or ''
end

---@param node table
---@return string[]
function File:get_node_text_list(node)
  return utils.get_node_text(node, self.file_content) or {}
end

---@param query string
---@param node table|nil
---@return table[]
function File:get_ts_matches(query, node)
  return utils.get_ts_matches(query, node or self.tree:root(), self.file_content, self.file_content_str)
end

---@return Section[]
function File:get_headlines()
  if self.is_archive_file then
    return {}
  end
  return self.sections
end

---@param path string
---@returns File
function File.load(path, callback)
  local ext = vim.fn.fnamemodify(path, ':e')
  if ext ~= 'org' and ext ~= 'org_archive' then
    return callback(nil)
  end
  local category = vim.fn.fnamemodify(path, ':t:r')
  utils.readfile(
    path,
    vim.schedule_wrap(function(err, content)
      if err then
        return callback(nil)
      end
      return callback(File.from_content(content, category, path, ext == 'org_archive'))
    end)
  )
end

---@param content string|table
---@param category string
---@param filename string
---@param is_archive_file boolean
---@return File|nil
function File.from_content(content, category, filename, is_archive_file)
  local str_content = table.concat(content, '\n')
  local trees = LanguageTree.new(str_content, 'org', {})
  trees = trees:parse()
  if #trees > 0 then
    return File:new(trees[1], content, str_content, category, filename, is_archive_file)
  end
  return nil
end

function File:refresh()
  local bufnr = vim.fn.bufnr(self.filename)
  if bufnr < 0 then
    return self
  end
  local changed = self.changedtick ~= vim.api.nvim_buf_get_var(bufnr, 'changedtick')
  if not changed then
    return self
  end
  local content = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local refreshed_file = File.from_content(content, self.category, self.filename, self.is_archive_file)
  refreshed_file.changedtick = vim.api.nvim_buf_get_var(bufnr, 'changedtick')
  if refreshed_file then
    return refreshed_file
  end
  return self
end

---@param search Search
---@param todo_only boolean
---@return Section[]
function File:apply_search(search, todo_only)
  if self.is_archive_file then
    return {}
  end

  return vim.tbl_filter(function(item)
    if item:is_archived() or (todo_only and not item:is_todo()) then
      return false
    end
    return search:check({
      props = item.properties.items,
      tags = item.tags,
      todo = item.todo_keyword.value,
    })
  end, self.sections)
end

---@param title string
---@return Section[]
function File:find_headlines_by_title(title)
  return vim.tbl_filter(function(item)
    return item.title:lower():match('^' .. vim.pesc(title:lower()))
  end, self.sections)
end

---@param property_name string
---@param term string
---@return Section[]
function File:find_headlines_with_property_matching(property_name, term)
  return vim.tbl_filter(function(item)
    return item.properties.items[property_name:lower()]
      and item.properties.items[property_name:lower()]:lower():match('^' .. vim.pesc(term:lower()))
  end, self.sections)
end

---@param search_term string
---@param no_escape boolean
---@param ignore_archive_flag boolean
---@return Section[]
function File:find_headlines_matching_search_term(search_term, no_escape, ignore_archive_flag)
  if self.is_archive_file and not ignore_archive_flag then
    return {}
  end
  local term = search_term:lower()
  if not no_escape then
    term = vim.pesc(term)
  end

  return vim.tbl_filter(function(item)
    return item:matches_search_term(term)
  end, self.sections)
end

---@param title string
---@return Section
function File:find_headline_by_title(title)
  local headlines = self:find_headlines_by_title(title)
  return headlines[1]
end

---@return Section[]
function File:get_opened_unfinished_headlines()
  if self.is_archive_file then
    return {}
  end

  return vim.tbl_filter(function(item)
    return not item:is_archived() and not item:is_done()
  end, self.sections)
end

---@return userdata
function File:get_node_at_cursor(cursor)
  cursor = cursor or vim.api.nvim_win_get_cursor(0)
  local cursor_range = { cursor[1] - 1, cursor[2] }
  return self.tree:root():named_descendant_for_range(cursor_range[1], cursor_range[2], cursor_range[1], cursor_range[2])
end

---@param id? string
---@return Section
function File:get_closest_headline(id)
  local node = nil
  if not id then
    node = self:get_node_at_cursor()
  else
    local cursor_range = { id - 1, vim.fn.col('$') - 2 }
    node = self.tree
      :root()
      :named_descendant_for_range(cursor_range[1], cursor_range[2], cursor_range[1], cursor_range[2])
  end

  if not node then
    return nil
  end
  while node and node:type() ~= 'section' do
    node = node:parent()
  end
  if not node then
    return nil
  end
  local start_line, _, _, _ = node:range()

  for _, section in ipairs(self.sections) do
    if section.range.start_line == (start_line + 1) then
      return section
    end
  end
  return nil
end

---@param from Date
---@param to Date
---@return table
function File:get_clock_report(from, to)
  local result = {
    total_duration = 0,
    headlines = {},
  }
  for _, section in ipairs(self.sections) do
    if section.logbook then
      local minutes = section.logbook:get_total_minutes(from, to)
      if minutes > 0 then
        table.insert(result.headlines, section)
        result.total_duration = result.total_duration + minutes
      end
    end
  end

  result.total_duration = Duration.from_minutes(result.total_duration)
  return result
end

---@param headline Section
---@return string[]
function File:get_headline_lines(headline)
  return self:get_node_text_list(headline.node)
end

---@return string
function File:get_archive_file_location()
  local matches = self:get_ts_matches('(document (directive (name) @name (value) @value (#eq? @name "ARCHIVE")))')
  if #matches > 0 then
    return config:parse_archive_location(self.filename, matches[1].value.text)
  end
  return config:parse_archive_location(self.filename)
end

---@param index number
---@return Section
function File:get_section(index)
  return self.sections[index]
end

---@private
function File:_parse_sections()
  for child in self.tree:root():iter_children() do
    if child:type() == 'section' then
      local section = Section.from_node(child, self)
      table.insert(self.sections, section)
      self.sections_by_line[section.line_number] = section
      self:_insert_child_sections(section)
    end
  end
end

---@param section Section
function File:_insert_child_sections(section)
  if section:is_clocked_in() then
    self.clocked_headline = section
  end
  if #section.sections == 0 then
    return
  end
  for _, child_section in ipairs(section.sections) do
    table.insert(self.sections, child_section)
    self.sections_by_line[child_section.line_number] = child_section
    self:_insert_child_sections(child_section)
  end
end

---@private
function File:_parse_source_code_filetypes()
  local blocks = self:get_ts_matches('(block name: (expr) @name parameter: (expr) @parameters (#eq? @name "SRC"))')
  local source_code_filetypes = {}
  for _, item in ipairs(blocks) do
    local ft = item.parameters and item.parameters.text
    if
      ft
      and ft ~= ''
      and not vim.tbl_contains(source_code_filetypes, ft)
      and vim.api.nvim_get_runtime_file('syntax/' .. ft:lower() .. '.vim', true)
    then
      table.insert(source_code_filetypes, ft)
    end
  end
  self.source_code_filetypes = source_code_filetypes
end

function File:_parse_directives()
  local directives = self:get_ts_matches([[(directive name: (expr) @name value: (value) @value)]])
  local tags = {}
  for _, directive in ipairs(directives) do
    if directive.name.text:lower() == 'filetags' then
      utils.concat(tags, utils.parse_tags_string(directive.value.text), true)
    end
  end
  self.tags = tags
end

return File

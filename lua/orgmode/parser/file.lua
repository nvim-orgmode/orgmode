local Range = require('orgmode.parser.range')
local Section = require('orgmode.parser.section')
local ts_utils = require('nvim-treesitter.ts_utils')
local LanguageTree = require('vim.treesitter.languagetree')
local config = require('orgmode.config')
local utils = require('orgmode.utils')

---@class File
---@field tree table
---@field file_content string
---@field category string
---@field filename string
---@field changedtick number
---@field sections Section[]
---@field source_code_filetypes string[]
---@field is_archive_file boolean
---@field clocked_headline Section
---@field tags string[]
local File = {}

function File:new(tree, file_content, category, filename, is_archive_file)
  local data = {
    tree = tree,
    file_content = file_content,
    category = category,
    filename = filename,
    changedtick = 0,
    sections = {},
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
  self:_parse_tags()
  self:_parse_sections()
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
  local node = ts_utils.get_node_at_cursor()
  return self:convert_to_file_node(node)
end

function File:get_opened_headlines()
  if self.is_archive_file then
    return {}
  end

  local headlines = vim.tbl_filter(function(item)
    return not item:is_archived()
  end, self.sections)

  table.sort(headlines, function(a, b)
    return a:get_priority_number() > b:get_priority_number()
  end)

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
  return utils.get_ts_matches(query, node or self.tree:root(), self.file_content)
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
    end),
    true
  )
end

---@param content string|table
---@param category string
---@param filename string
---@param is_archive_file boolean
---@return File|nil
function File.from_content(content, category, filename, is_archive_file)
  if type(content) == 'table' then
    content = table.concat(content, '\n')
  end
  local trees = LanguageTree.new(content, 'org', {})
  trees = trees:parse()
  if #trees > 0 then
    return File:new(trees[1], content, category, filename, is_archive_file)
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
    return item.properties.items[property_name]
      and item.properties.items[property_name]:lower():match('^' .. vim.pesc(term:lower()))
  end, self.sections)
end

---@param search_term string
---@param no_escape boolean
---@return Section[]
function File:find_headlines_matching_search_term(search_term, no_escape)
  if self.is_archive_file then
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

---@param id? string
---@return Section
function File:get_closest_headline(id)
  local node = nil
  if not id then
    node = ts_utils.get_node_at_cursor()
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
  local sections = self:get_ts_matches('(document (section) @section)')
  for _, section_item in ipairs(sections) do
    local section = Section.from_node(section_item.section.node, self)
    if section:is_clocked_in() then
      self.clocked_headline = section
    end
    table.insert(self.sections, section)
    self:_insert_child_sections(section)
  end
end

---@param section Section
function File:_insert_child_sections(section)
  if #section.sections == 0 then
    return
  end
  for _, child_section in ipairs(section.sections) do
    table.insert(self.sections, child_section)
    self:_insert_child_sections(child_section)
  end
end

---@private
function File:_parse_source_code_filetypes()
  local blocks = self:get_ts_matches('(block (name) @name (parameters) @parameters (#eq? @name "SRC"))')
  local source_code_filetypes = {}
  for _, item in ipairs(blocks) do
    local params = vim.split(item.parameters.text, '%s+')
    local ft = params[1]
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

function File:_parse_tags()
  local matches = self:get_ts_matches('(document (directive (name) @name (value) @value (#eq? @name "FILETAGS")))')
  if #matches > 0 then
    self.tags = utils.parse_tags_string(matches[1].value.text)
  end
end

return File

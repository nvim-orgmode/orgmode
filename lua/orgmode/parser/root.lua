local Headline = require('orgmode.parser.headline')
local Content = require('orgmode.parser.content')
local Config = require('orgmode.config')
local Types = require('orgmode.parser.types')
local Range = require('orgmode.parser.range')
local utils = require('orgmode.utils')

---@class Root
---@field lines string[]
---@field content Content[]
---@field headlines Headline[]
---@field items Headline[]|Content[]
---@field source_code_filetypes string[]
---@field level number
---@field category string
---@field file string
---@field range Range
---@field id number
---@field tags string[]
---@field is_archive_file boolean
local Root = {}

---@param lines string[]
---@param category string
---@param file string
---@param is_archive_file boolean
function Root:new(lines, category, file, is_archive_file)
  local data = {
    lines = lines,
    content = {},
    headlines = {},
    items = {},
    level = 0,
    category = category or '',
    file = file or '',
    range = Range:new({
      start_line = 1,
      end_line = #lines,
    }),
    id = 0,
    tags = {},
    source_code_filetypes = {},
    is_archive_file = is_archive_file or false,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param headline_data table
---@return Headline
function Root:add_headline(headline_data)
  headline_data.category = self.category
  headline_data.file = self.file
  headline_data.archived = self.is_archive_file
  local headline = Headline:new(headline_data)
  self.items[headline.id] = headline
  local plevel = headline.parent.level
  if plevel > 0 and plevel < headline.level then
    headline.parent:add_headline(headline)
  end
  if headline.level == 1 then
    self:add_root_headline(headline)
  end
  return headline
end

---@param content_data table
---@return Content
function Root:add_content(content_data)
  local content = Content:new(content_data)
  self.items[content.id] = content

  if content:is_keyword() then
    self:add_root_content(content)
    return content
  end

  if content:is_block_src_start() then
    self:_add_source_block(content)
  end

  if content.parent.level > 0 then
    content.parent:add_content(content)
  end
end

---@param headline Headline
---@param level number
---@return Headline
function Root:get_parent_for_level(headline, level)
  local parent = headline.parent or self
  while parent.level > (level - 1) do
    parent = parent.parent
  end
  return parent
end

---@param content Content
function Root:add_root_content(content)
  table.insert(self.content, content)
  self:process_root_content(content)
end

---@param headline Headline
function Root:add_root_headline(headline)
  table.insert(self.headlines, headline)
end

---@param item Headline|Content
---@return Headline
function Root:get_parent(item)
  if not item.parent or item.parent == 0 then
    return self
  end
  return self.items[item.parent]
end

---@param headline Headline
---@param lnum number
---@param level number
function Root:set_headline_end(headline, lnum, level)
  while headline.level >= level do
    headline:set_range_end(lnum)
    headline = headline.parent
  end
end

---@param content Content
---@return string
function Root:process_root_content(content)
  if content:is_keyword() and content.keyword.name == 'FILETAGS' then
    local filetags = utils.parse_tags_string(content.keyword.value)
    for _, tag in ipairs(filetags) do
      if not vim.tbl_contains(self.tags, tag) then
        table.insert(self.tags, tag)
      end
    end
  end
end

---@return Headline|Content[]
function Root:get_items()
  return self.items
end

---@return Headline|Content
function Root:get_item(id)
  return self.items[id]
end

function Root:get_current_item()
  return self:get_item(vim.fn.line('.'))
end

function Root:get_headlines()
  if self.is_archive_file then return {} end
  return vim.tbl_filter(function(item) return item:is_headline() end, self.items)
end

---@return Headline[]
function Root:get_opened_headlines()
  if self.is_archive_file then return {} end

  local headlines = vim.tbl_filter(function(item)
   return item.type == Types.HEADLINE and not item:is_archived()
  end, self.items)

  table.sort(headlines, function(a, b)
    return a:get_priority_number() > b:get_priority_number()
  end)

  return headlines
end

---@return Headline[]
function Root:get_opened_unfinished_headlines()
  if self.is_archive_file then return {} end

  return vim.tbl_filter(function(item)
   return item.type == Types.HEADLINE and not item:is_archived() and not item:is_done()
  end, self.items)
end

function Root:get_unfinished_todo_entries()
  if self.is_archive_file then return {} end

  return vim.tbl_filter(function(item)
   return item.type == Types.HEADLINE and not item:is_archived() and item:is_todo()
  end, self.items)
end

function Root:find_headlines_matching_search_term(search_term, no_escape)
  if self.is_archive_file then return {} end
  local term = search_term:lower()
  if not no_escape then
    term = vim.pesc(term)
  end

  return vim.tbl_filter(function(item)
    local is_match = false
    if item.type == Types.HEADLINE then
      is_match = item.title:lower():match(term)
      if not is_match then
        for _, content in ipairs(item.content) do
          if content.line:lower():match(term) then
            is_match = true
            break
          end
        end
      end
      return is_match
    end
  end, self.items)
end

function Root:find_headlines_by_title(title)
  return vim.tbl_filter(function(item)
    return item.type == Types.HEADLINE and item.title:lower():match('^'..vim.pesc(title:lower()))
  end, self.items)
end

function Root:find_headlines_with_property_matching(property_name, term)
  return vim.tbl_filter(function(item)
    return item.type == Types.HEADLINE
      and item.properties.items[property_name]
      and item.properties.items[property_name]:lower():match('^'..vim.pesc(term:lower()))
  end, self.items)
end

function Root:find_headline_by_title(title)
  local headlines = self:find_headlines_by_title(title)
  return headlines[1]
end

---@param id? string
---@return Headline
function Root:get_closest_headline(id)
  local item = self:get_item(id or vim.fn.line('.'))
  if item.type ~= Types.HEADLINE then
    item = item.parent
  end
  return item
end

function Root:get_headline_lines(headline)
  return {unpack(self.lines, headline.range.start_line, headline.range.end_line)}
end

---@param search Search
---@param todo_only boolean
---@return Headline[]
function Root:apply_search(search, todo_only)
  if self.is_archive_file then return {} end

  return vim.tbl_filter(function(item)
    if not item:is_headline() or item:is_archived() or (todo_only and not item:is_todo()) then return false end
    return search:check({
      props = item.properties.items,
      tags = item.tags,
      todo = item.todo_keyword.value,
    })
  end, self.items)
end

function Root:_add_source_block(content)
  local filetype = content.line:match('^%s*#%+BEGIN_SRC%s+(.*)%s*$')
  if not filetype then return end
  filetype = vim.trim(filetype)
  if not vim.tbl_contains(self.source_code_filetypes, filetype) then
    table.insert(self.source_code_filetypes, filetype)
  end
end

function Root:get_archive_file_location()
  for _, content in ipairs(self.content) do
    if content:is_keyword() and content.keyword.name == 'ARCHIVE' then
      return Config:parse_archive_location(self.file, content.keyword.value)
    end
  end
  return Config:parse_archive_location(self.file)
end

return Root

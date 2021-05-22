local Headline = require('orgmode.parser.headline')
local Content = require('orgmode.parser.content')
local Types = require('orgmode.parser.types')
local Range = require('orgmode.parser.range')
local config = require('orgmode.config')

---@class Root
---@field lines string[]
---@field content Content[]
---@field items Headline[]|Content[]
---@field level number
---@field category string
---@field file string
---@field range Range
---@field id number
---@field tags string[]
local Root = {}

---@param lines string[]
---@param category string
---@param file string
function Root:new(lines, category, file)
  local data = {
    lines = lines,
    content = {},
    items = {},
    level = 0,
    category = category or '',
    file = file or '',
    range = Range:new({
      start_line = 1,
      end_line = #lines,
    }),
    id = 0,
    tags = {}
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
  local headline = Headline:new(headline_data)
  self.items[headline.id] = headline
  local plevel = headline_data.parent.level
  if plevel > 0 and plevel < headline.level then
    headline_data.parent:add_headline(headline)
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
  elseif content_data.parent.level > 0 then
    content_data.parent:add_content(content)
  end
  return content
end

---@param headline Headline
---@param level number
---@return Headline
function Root:get_parent_for_level(headline, level)
  local parent = self:get_parent(headline)
  while parent.level > (level - 1) do
    parent = self:get_parent(parent)
  end
  return parent
end

---@param content Content
function Root:add_root_content(content)
  table.insert(self.content, content)
  self:process_root_content(content)
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
    headline:set_range_end(lnum - 1)
    headline = self:get_parent(headline)
  end
end

---@param content Content
---@return string
function Root:process_root_content(content)
  if content:is_keyword() and content.keyword.name == 'FILETAGS' then
    for _, tag in ipairs(vim.split(content.keyword.value, '%s*,%s*')) do
      if tag:find('^[%w_%%@#]+$') and not vim.tbl_contains(self.tags, tag) then
        table.insert(self.tags, tag)
      end
    end
  end
end

---@return Headline[]|Content[]
function Root:get_items()
  return self.items
end

---@return Headline[]
function Root:get_opened_headlines()
  return vim.tbl_filter(function(item)
   return item.type == Types.HEADLINE and not item:is_archived()
  end, self.items)
end

---@return Headline[]
function Root:get_headlines_for_today()
  return vim.tbl_filter(function(item)
   return item.type == Types.HEADLINE and not item:is_archived() and not item:is_done()
  end, self.items)
end

return Root

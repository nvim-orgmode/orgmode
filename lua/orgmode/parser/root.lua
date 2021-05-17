local Headline = require('orgmode.parser.headline')
local Content = require('orgmode.parser.content')
local Types = require('orgmode.parser.types')
local Root = {}

function Root:new(lines, filename)
  local data = {
    lines = lines,
    content = {},
    items = {},
    level = 0,
    category = filename or '',
    range = {
      from = { line = 1, col = 1 },
      to = { line = #lines, col = 1 },
    },
    id = 0,
    tags = {}
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Root:add_headline(headline_data)
  local headline = Headline:new(headline_data)
  self.items[headline.id] = headline
  local plevel = headline_data.parent.level
  if plevel > 0 and plevel < headline.level then
    headline_data.parent:add_headline(headline)
  end
  return headline
end

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

function Root:get_parent_for_level(headline, level)
  local parent = self:get_parent(headline)
  while parent.level > (level - 1) do
    parent = self:get_parent(parent)
  end
  return parent
end

function Root:add_root_content(content)
  table.insert(self.content, content)
  self:process_root_content(content)
end

function Root:get_parent(item)
  if not item.parent or item.parent == 0 then
    return self
  end
  return self.items[item.parent]
end

function Root:set_headline_end(headline, lnum, level)
  while headline.level >= level do
    headline:set_range_end(lnum - 1)
    headline = self:get_parent(headline)
  end
end

function Root:process_root_content(content)
  if content:is_keyword() and content.keyword.name == 'FILETAGS' then
    for _, tag in ipairs(vim.split(content.keyword.value, '%s*,%s*')) do
      if tag:find('^[%w_%%@#]+$') and not vim.tbl_contains(self.tags, tag) then
        table.insert(self.tags, tag)
      end
    end
  end
end

function Root:get_headlines()
  return vim.tbl_filter(function(item)
    return item.type == Types.HEADLINE
  end,self.items)
end

function Root:get_items()
  return self.items
end

function Root:get_category(headline)
  if headline.category then
    return headline.category
  end
  return self.category
end

function Root:finish_parsing()
  return self
end

return Root

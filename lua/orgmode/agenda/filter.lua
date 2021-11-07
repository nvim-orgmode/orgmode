local utils = require('orgmode.utils')
---@class AgendaFilter
---@field value string
---@field available_tags table<string, boolean>
---@field available_categories table<string, boolean>
---@field tags string[]
---@field categories string[]
---@field tags_and_categories string[]
---@field term string
---@field parsed boolean
---@field applying boolean
local AgendaFilter = {}

function AgendaFilter:new()
  local data = {
    value = '',
    available_tags = {},
    available_categories = {},
    tags = {},
    categories = {},
    tags_and_categories = {},
    term = '',
    parsed = false,
    applying = false,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

---@return boolean
function AgendaFilter:should_filter()
  return vim.trim(self.value) ~= ''
end

---@param headline Section
---@return boolean
function AgendaFilter:matches(headline)
  if not self:should_filter() then
    return true
  end
  local term_match = vim.trim(self.term) == ''
  local tag_cat_match = #self.tags == 0 and #self.categories == 0
  if not term_match then
    local rgx = vim.regex(self.term)
    term_match = rgx:match_str(headline.title)
  end
  if not tag_cat_match then
    for _, tag in ipairs(self.tags) do
      if not headline:has_tag(tag) then
        return false
      end
    end
    tag_cat_match = #self.categories == 0

    for _, category in ipairs(self.categories) do
      if headline:matches_category(category) then
        return term_match
      end
    end
  end

  return term_match and tag_cat_match
end

---@param filter string
function AgendaFilter:parse(filter)
  filter = filter or ''
  self.value = filter
  self.tags = {}
  self.categories = {}
  local search_rgx = '/[^/]*/?'
  local search_term = filter:match(search_rgx)
  if search_term then
    search_term = search_term:gsub('^/*', ''):gsub('/*$', '')
  end
  filter = filter:gsub(search_rgx, '')
  for _, tag_cat in ipairs(vim.split(filter, '[%+%-]') or {}) do
    local val = vim.trim(tag_cat)
    if val ~= '' then
      if self.available_tags[val] then
        table.insert(self.tags, val)
      elseif self.available_categories[val] then
        table.insert(self.categories, val)
      end
    end
  end
  self.term = search_term or ''
  self.applying = true
end

function AgendaFilter:reset()
  self.value = ''
  self.tags_and_categories = {}
  self.term = ''
  self.parsed = false
  self.applying = false
end

---@param content table[]
function AgendaFilter:parse_tags_and_categories(content)
  if self.parsed then
    return
  end
  local tags = {}
  local categories = {}
  for _, item in ipairs(content) do
    if item.jumpable and item.headline then
      categories[item.headline.category:lower()] = true
      for _, tag in ipairs(item.headline.tags) do
        tags[tag:lower()] = true
      end
    end
  end
  self.available_tags = tags
  self.available_categories = categories
  self.parsed = true
end

---@return string[]
function AgendaFilter:get_completion_list()
  local list = vim.tbl_keys(self.available_tags)
  return utils.concat(list, vim.tbl_keys(self.available_categories), true)
end

return AgendaFilter

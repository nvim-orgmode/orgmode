local utils = require('orgmode.utils')
---@class OrgAgendaFilter
---@field value string
---@field available_tags table<string, boolean>
---@field available_categories table<string, boolean>
---@field filter_type 'include' | 'exclude'
---@field tags table[]
---@field categories table[]
---@field term string
---@field parsed boolean
---@field applying boolean
local AgendaFilter = {}

function AgendaFilter:new()
  local data = {
    value = '',
    available_tags = {},
    available_categories = {},
    filter_type = 'exclude',
    tags = {},
    categories = {},
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

---@param headline OrgHeadline
---@return boolean
function AgendaFilter:matches(headline)
  if not self:should_filter() then
    return true
  end
  local term_match = vim.trim(self.term) == ''
  local tag_cat_match_empty = #self.tags == 0 and #self.categories == 0

  if not term_match then
    local rgx = vim.regex(self.term) --[[@as vim.regex]]
    term_match = rgx:match_str(headline:get_title()) and true or false
  end

  if tag_cat_match_empty then
    return term_match
  end

  local tag_cat_match = false

  if self.filter_type == 'include' then
    tag_cat_match = self:_matches_include(headline)
  else
    tag_cat_match = self:_matches_exclude(headline)
  end

  return tag_cat_match and term_match
end

---@param headline OrgHeadline
---@private
function AgendaFilter:_matches_exclude(headline)
  for _, tag in ipairs(self.tags) do
    if headline:has_tag(tag.value) then
      return false
    end
  end

  for _, category in ipairs(self.categories) do
    if headline:matches_category(category.value) then
      return false
    end
  end

  return true
end

---@param headline OrgHeadline
---@private
function AgendaFilter:_matches_include(headline)
  local tags_to_check = {}
  local categories_to_check = {}

  for _, tag in ipairs(self.tags) do
    if tag.operator == '-' then
      if headline:has_tag(tag.value) then
        return false
      end
    else
      table.insert(tags_to_check, tag.value)
    end
  end

  for _, category in ipairs(self.categories) do
    if category.operator == '-' then
      if headline:matches_category(category.value) then
        return false
      end
    else
      table.insert(categories_to_check, category.value)
    end
  end

  local tags_passed = #tags_to_check == 0
  local categories_passed = #categories_to_check == 0

  for _, category in ipairs(categories_to_check) do
    if headline:matches_category(category) then
      categories_passed = true
      break
    end
  end

  for _, tag in ipairs(tags_to_check) do
    if headline:has_tag(tag) then
      tags_passed = true
      break
    end
  end

  return tags_passed and categories_passed
end

---@param filter string
---@param skip_check? boolean do not check if given values exist in the current view
function AgendaFilter:parse(filter, skip_check)
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
  for operator, tag_cat in string.gmatch(filter, '([%+%-]*)([^%-%+]+)') do
    if not operator or operator == '' or operator == '+' then
      self.filter_type = 'include'
    end
    local val = vim.trim(tag_cat)
    if val ~= '' then
      if self.available_tags[val] or skip_check then
        table.insert(self.tags, { operator = operator, value = val })
      elseif self.available_categories[val] or skip_check then
        table.insert(self.categories, { operator = operator, value = val })
      end
    end
  end
  self.term = search_term or ''
  self.applying = true
  if skip_check then
    self.parsed = true
  end
end

function AgendaFilter:reset()
  self.value = ''
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
      categories[item.headline:get_category():lower()] = true
      for _, tag in ipairs(item.headline:get_tags()) do
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

---@class OrgAgendaFilter
---@field value string
---@field available_values table<string, boolean>
---@field types? ('tags' | 'categories')[]
---@field values table[]
---@field term string
---@field parsed boolean
local AgendaFilter = {}

---@param opts? { types?: ('tags' | 'categories')[] }
---@return OrgAgendaFilter
function AgendaFilter:new(opts)
  opts = opts or {}
  local data = {
    value = '',
    available_values = {},
    values = {},
    term = '',
    types = opts.types or { 'tags', 'categories' },
    parsed = false,
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
  local values_match_empty = #self.values == 0

  if not term_match then
    local rgx = vim.regex(self.term) --[[@as vim.regex]]
    term_match = rgx:match_str(headline:get_title()) and true or false
  end

  if values_match_empty then
    return term_match
  end

  local tag_cat_match = self:_match(headline)

  return tag_cat_match and term_match
end

---@private
---@param headline OrgHeadline
---@return boolean
function AgendaFilter:_match(headline)
  local filters = {}
  if vim.tbl_contains(self.types, 'tags') then
    table.insert(filters, function(tag)
      return headline:has_tag(tag)
    end)
  end
  if vim.tbl_contains(self.types, 'categories') then
    table.insert(filters, function(category)
      return headline:matches_category(category)
    end)
  end
  for _, value in ipairs(self.values) do
    if value.operator == '-' then
      for _, filter in ipairs(filters) do
        if filter(value.value) then
          return false
        end
      end
    else
      local result = vim.tbl_filter(function(filter)
        return filter(value.value)
      end, filters)
      if #result == 0 then
        return false
      end
    end
  end

  return true
end

---@param filter string
---@param skip_check? boolean do not check if given values exist in the current view
function AgendaFilter:parse(filter, skip_check)
  filter = filter or ''
  self.value = filter
  self.values = {}
  local search_rgx = '/[^/]*/?'
  local search_term = filter:match(search_rgx)
  if search_term then
    search_term = search_term:gsub('^/*', ''):gsub('/*$', '')
  end
  filter = filter:gsub(search_rgx, '')
  for operator, tag_cat in string.gmatch(filter, '([%+%-]*)([^%-%+]+)') do
    local val = vim.trim(tag_cat)
    if val ~= '' then
      if self.available_values[val] or skip_check then
        table.insert(self.values, { operator = operator, value = val })
      end
    end
  end
  self.term = search_term or ''
  return self
end

function AgendaFilter:reset()
  self.value = ''
  self.term = ''
  self.parsed = false
end

---@param agenda_views OrgAgendaViewType[]
function AgendaFilter:parse_available_filters(agenda_views)
  if self.parsed then
    return
  end
  local values = {}
  for _, agenda_view in ipairs(agenda_views) do
    for _, line in ipairs(agenda_view:get_lines()) do
      if line.headline then
        if vim.tbl_contains(self.types, 'categories') then
          values[line.headline:get_category()] = true
        end
        if vim.tbl_contains(self.types, 'tags') then
          for _, tag in ipairs(line.headline:get_tags()) do
            values[tag] = true
          end
        end
      end
    end
  end
  self.available_values = values
  self.parsed = true
end

---@return string[]
function AgendaFilter:get_completion_list()
  return vim.tbl_keys(self.available_values)
end

return AgendaFilter

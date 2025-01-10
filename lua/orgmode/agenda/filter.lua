---@class OrgAgendaFilter
---@field value string
---@field available_values table<string, boolean>
---@field values table[]
---@field term string
---@field parsed boolean
local AgendaFilter = {}

---@return OrgAgendaFilter
function AgendaFilter:new()
  local data = {
    value = '',
    available_values = {},
    values = {},
    term = '',
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
  for _, value in ipairs(self.values) do
    if value.operator == '-' then
      if headline:has_tag(value.value) or headline:matches_category(value.value) then
        return false
      end
    elseif not headline:has_tag(value.value) and not headline:matches_category(value.value) then
      return false
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
        values[line.headline:get_category()] = true
        for _, tag in ipairs(line.headline:get_tags()) do
          values[tag] = true
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

local Calendar = require('orgmode.objects.calendar')
local Date = require('orgmode.objects.date')
local TodoState = require('orgmode.objects.todo_state')
local utils = require('orgmode.utils')

---@class OrgMappings
---@field files OrgFiles
local OrgMappings = {}

---@param data table
function OrgMappings:new(data)
  local opts = {}
  opts.files = data.files
  setmetatable(opts, self)
  self.__index = self
  return opts
end

-- TODO: Add hierarchy
function OrgMappings:toggle_checkbox()
  local line = vim.fn.getline('.')
  local pattern = '^(%s*[%-%+]%s*%[([%sXx]?)%])'
  local checkbox, state = line:match(pattern)
  if not checkbox then return end
  local new_val = vim.trim(state) == '' and '[X]' or '[ ]'
  checkbox = checkbox:gsub('%[[%sXx]?%]$', new_val)
  local new_line = line:gsub(pattern, checkbox)
  vim.fn.setline('.', new_line)
end

function OrgMappings:increase_date()
  return self:_adjust_date('+1d', '<C-a>')
end

function OrgMappings:decrease_date()
  return self:_adjust_date('-1d','<C-x>')
end

function OrgMappings:change_date()
  local date = self:_get_date_under_cursor()
  if not date then return end
  local cb = function(new_date)
    self:_replace_date(new_date)
  end
  Calendar.new({ callback = cb, date = date }).open()
end

function OrgMappings:todo_next_state()
  local item = self.files:get_current_file():get_closest_headline(vim.fn.line('.'))
  local old_state = item.todo_keyword.value
  self:_change_todo_state('next')
  item = self.files:get_current_file():get_closest_headline(vim.fn.line('.'))
  if not item:is_done() then return item end

  local repeater_dates = item:get_repeater_dates()
  if #repeater_dates == 0 then return item end

  for _, date in ipairs(repeater_dates) do
    self:_replace_date(date:apply_repeater())
  end

  self:_change_todo_state('reset')
  local state_change = string.format('- State "%s" from "%s" [%s]', item.todo_keyword.value, old_state, Date.now():to_string())

  if not item.properties.LAST_REPEAT then
    local properties_line = item:get_new_properties_line()
    vim.fn.append(properties_line, {
      ':PROPERTIES:',
      ':LAST_REPEAT: ['..Date.now():to_string()..']',
      ':END:',
      state_change
    })
    return item
  end

  local prev_state_changes = item:get_content_matching('^%s*-%s*State%s*"%w+"%s+from%s+"%w+"')
  if prev_state_changes then
    vim.fn.append(prev_state_changes.range.start_line, state_change)
    return item
  end

  local properties_end = item:get_content_matching('^%s*:END:%s*$')
  if properties_end then
    vim.fn.append(properties_end.range.start_line, state_change)
  end
end

function OrgMappings:todo_prev_state()
  self:_change_todo_state('prev')
end

---@param direction string
function OrgMappings:_change_todo_state(direction)
  local item = self.files:get_current_file():get_closest_headline(vim.fn.line('.'))
  local todo = item.todo_keyword
  local todo_state = TodoState:new({ current_state = todo.value })
  local next_state = nil
  if direction == 'next' then
    next_state = todo_state:get_next()
  elseif direction == 'prev' then
    next_state = todo_state:get_prev()
  elseif direction == 'reset' then
    next_state = todo_state:get_todo()
  end

  local linenr = item.range.start_line
  local stars = vim.fn['repeat']('%*', item.level)
  local old_state = todo.value
  if old_state ~= '' then
    old_state = old_state..'%s+'
  end
  local new_state = next_state.value
  if new_state ~= '' then
    new_state = new_state..' '
  end
  local new_line = vim.fn.getline(linenr):gsub('^'..stars..'%s+'..old_state, stars..' '..new_state)
  vim.fn.setline(linenr, new_line)
end

---@param date Date
function OrgMappings:_replace_date(date)
  local line = vim.fn.getline(date.range.start_line)
  local view = vim.fn.winsaveview()
  vim.fn.setline(date.range.start_line, string.format('%s%s%s', line:sub(1, date.range.start_col), date:to_string(), line:sub(date.range.end_col)))
  vim.fn.winrestview(view)
end

---@return Date|nil
function OrgMappings:_get_date_under_cursor()
  local item = self.files:get_current_item()
  local col = vim.fn.col('.')
  local line = vim.fn.line('.')
  local dates = vim.tbl_filter(function(date)
    return date.range:is_in_range(line, col)
  end, item.dates)

  if #dates == 0 then return nil end

  return dates[1]
end

---@param adjustment string
---@param fallback function
---@return string
function OrgMappings:_adjust_date(adjustment, fallback)
  local date = self:_get_date_under_cursor()
  if not date then
    return vim.api.nvim_feedkeys(utils.esc(fallback), 'n', true)
  end
  local new_date = date:adjust(adjustment)
  return self:_replace_date(new_date)
end

return OrgMappings

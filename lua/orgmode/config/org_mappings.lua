---@class OrgMappings
---@field files OrgFiles
local OrgMappings = {}
local Calendar = require('orgmode.objects.calendar')
local TodoState = require('orgmode.objects.todo_state')
local utils = require('orgmode.utils')

---@param data table
function OrgMappings:new(data)
  local opts = {}
  opts.files = data.files
  setmetatable(opts, self)
  self.__index = self
  return opts
end

function OrgMappings:adjust_date(adjustment, fallback)
  local date = self:_get_date_under_cursor()
  if not date then
    return vim.api.nvim_feedkeys(utils.esc(fallback), 'n', true)
  end
  local new_date = date:adjust(adjustment)
  return self:_replace_date(new_date)
end

function OrgMappings:_replace_date(date)
  local line = vim.fn.getline('.')
  local view = vim.fn.winsaveview()
  vim.fn.setline(vim.fn.line('.'), string.format('%s%s%s', line:sub(1, date.range.start_col), date:to_string(), line:sub(date.range.end_col)))
  vim.fn.winrestview(view)
end

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

function OrgMappings:increase_date()
  return self:adjust_date('+1d', '<C-a>')
end

function OrgMappings:decrease_date()
  return self:adjust_date('-1d','<C-x>')
end

function OrgMappings:change_date()
  local date = self:_get_date_under_cursor()
  if not date then return end
  local cb = function(new_date)
    self:_replace_date(new_date)
  end
  Calendar.new({ callback = cb, date = date }).open()
end

-- TODO: Update headline with more data after changing to DONE state
function OrgMappings:todo_next_state()
  return self:_change_todo_state('next')
end

function OrgMappings:todo_prev_state()
  return self:_change_todo_state('prev')
end

function OrgMappings:_change_todo_state(direction)
  local item = self.files:get_current_file():get_closest_headline(vim.fn.line('.'))
  local todo = item.todo_keyword
  local todo_state = TodoState:new({ current_state = todo.value })
  local next_state = nil
  if direction == 'next' then
    next_state = todo_state:get_next()
  else
    next_state = todo_state:get_prev()
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

return OrgMappings

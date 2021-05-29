---@class OrgMappings
---@field files OrgFiles
local OrgMappings = {}
local Date = require('orgmode.objects.date')
local Calendar = require('orgmode.objects.calendar')
local TodoState = require('orgmode.objects.todo_state')
local utils = require('orgmode.utils')
local pairs = {
  ['<'] = '>',
  ['['] = ']',
}

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
  local dates = vim.tbl_filter(function(date)
    return date.range:is_col_in_range(col)
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

function OrgMappings:change_todo_state()
  local item = self.files:get_current_file():get_closest_headline(vim.fn.line('.'))
  local todo = item.todo_keyword
  local todo_state = TodoState:new({ current_state = todo.value })
  local next_state = todo_state:get_next()
  local linenr = todo.range.start_line
  local line = vim.fn.getline(linenr)
  if next_state.value == '' then
    return vim.fn.setline(linenr, string.format('%s%s%s', line:sub(1, todo.range.start_col - 1), '', line:sub(todo.range.end_col + 2)))
  end
  vim.fn.setline(linenr, string.format('%s%s%s', line:sub(1, todo.range.start_col - 1), next_state.value, line:sub(todo.range.start_col + next_state.value:len())))
end

return OrgMappings

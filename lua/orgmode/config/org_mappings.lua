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
  local data = self:_get_date_under_cursor()
  if not data then
    return vim.api.nvim_feedkeys(utils.esc(fallback), 'n', true)
  end
  local date = data.date:adjust(adjustment)
  return self:_replace_date(data, date)
end

function OrgMappings:_replace_date(data, date)
  local line = vim.fn.getline('.')
  local view = vim.fn.winsaveview()
  vim.fn.setline(vim.fn.line('.'), string.format('%s%s%s', line:sub(1, data.start - 1), date:to_string(), line:sub(data.finish + 1)))
  vim.fn.winrestview(view)
end

function OrgMappings:_get_date_under_cursor()
  local line = vim.fn.getline('.')
  local last_col = vim.fn.col('$')
  local start = vim.fn.col('.')
  local finish = vim.fn.col('.')
  local char = nil
  while start > 0 do
    local c = line:sub(start, start)
    if c == '<' or c == '[' then
      char = c
      start = start + 1
      break
    end
    start = start - 1
  end

  if start == 0 or not char then return nil end

  while finish < last_col do
    local c = line:sub(finish, finish)
    if c == pairs[char] then
      finish = finish - 1
      break
    end
    finish = finish + 1
  end

  local selection = line:sub(start, finish)
  if not Date.is_valid_date(selection) then
    return nil
  end

  return {
    start = start,
    finish = finish,
    date = Date.from_string(selection)
  }
end

function OrgMappings:increase_date()
  return self:adjust_date('+1d', '<C-a>')
end

function OrgMappings:decrease_date()
  return self:adjust_date('-1d','<C-x>')
end

function OrgMappings:change_date()
  local data = self._get_date_under_cursor()
  if not data then return end
  local cb = function(date)
    self:_replace_date(data, date)
  end
  Calendar.new({ callback = cb, date = data.date }).open()
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

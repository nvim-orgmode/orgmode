---@class OrgMappings
---@field agenda Agenda
local OrgMappings = {}
local Date = require('orgmode.objects.date')
local Calendar = require('orgmode.objects.calendar')
local utils = require('orgmode.utils')
local pairs = {
  ['<'] = '>',
  ['['] = ']',
}

---@param data table
function OrgMappings:new(data)
  local opts = {}
  opts.agenda = data.agenda
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

return OrgMappings

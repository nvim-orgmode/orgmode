---@class OrgMappings
---@field agenda Agenda
local OrgMappings = {}
local Date = require('orgmode.objects.date')
local Calendar = require('orgmode.objects.calendar')
local utils = require('orgmode.utils')

---@param data table
function OrgMappings:new(data)
  local opts = {}
  opts.agenda = data.agenda
  setmetatable(opts, self)
  self.__index = self
  return opts
end

function OrgMappings:adjust_date(adjustment, fallback)
  local line = vim.fn.getline('.')
  local last_col = vim.fn.col('$')
  local start = vim.fn.col('.')
  local finish = vim.fn.col('.')
  while start > 0 do
    local c = line:sub(start, start)
    if c == '<' or c == '[' then
      start = start + 1
      break
    end
    start = start - 1
  end

  while finish < last_col do
    local c = line:sub(finish, finish)
    if c == '>' or c == ']' then
      finish = finish - 1
      break
    end
    finish = finish + 1
  end

  if start == 0 or finish == last_col then
    return vim.api.nvim_feedkeys(utils.esc(fallback), 'n', true)
  end
  local selection = line:sub(start, finish)
  if not Date.is_valid_date(selection) then return end
  local date = Date.from_string(selection):adjust(adjustment):to_string()
  local view = vim.fn.winsaveview()
  vim.fn.setline(vim.fn.line('.'), string.format('%s%s%s', line:sub(1, start - 1), date, line:sub(finish + 1)))
  vim.fn.winrestview(view)
end

function OrgMappings:increase_date()
  return self:adjust_date('+1d', '<C-a>')
end

function OrgMappings:decrease_date()
  return self:adjust_date('-1d','<C-x>')
end

function OrgMappings:change_date()
  -- TODO: Tweak
  local cb = function(date)
    vim.cmd('norm!ci<'..date:to_string())
  end
  Calendar.new({ callback = cb }).open()
end

return OrgMappings

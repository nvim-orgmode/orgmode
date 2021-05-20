local instance = {}
local Config = {}
local utils = require('orgmode.utils')
local defaults = require('orgmode.config.defaults')

---@class Config
---@param opts? table
function Config:new(opts)
  opts = opts or {}
  local data = vim.tbl_extend('force', defaults, opts)
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param opts table
---@return Config
function Config:extend(opts)
  instance = self:new(vim.tbl_extend('force', self, opts or {}))
  return instance
end

---@return string[]
function Config:get_all_files()
  if not self.org_agenda_files or self.org_agenda_files == '' then
    return {}
  end
  return vim.fn.glob(vim.fn.fnamemodify(self.org_agenda_files, ':p'), 0, 1)
end

---@return number
function Config:get_week_start_day_number()
  return utils.convert_from_isoweekday(1)
end

---@return number
function Config:get_week_end_day_number()
  return utils.convert_from_isoweekday(7)
end

---@return string|number
function Config:get_agenda_span()
  local span = self.org_agenda_span
  local valid_spans = {'day', 'month', 'week', 'year'}
  if type(span) == 'string' and not vim.tbl_contains(valid_spans, span) then
    utils.echo_warning(string.format(
      'Invalid agenda span %s. Valid spans: %s. Falling back to week',
      span,
      table.concat(valid_spans, ', ')
    ))
    span = 'week'
  end
  if type(span) == 'number' and span < 0 then
    utils.echo_warning(string.format(
      'Invalid agenda span number %d. Must be 0 or more. Falling back to week',
      span,
      table.concat(valid_spans, ', ')
    ))
    span = 'week'
  end
  return span
end

instance = Config:new()
return instance

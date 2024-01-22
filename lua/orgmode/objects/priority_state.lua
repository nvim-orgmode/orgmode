local config = require('orgmode.config')
local utils = require('orgmode.utils')

---@class OrgPriorityState
---@field high_priority string
---@field low_priority string
---@field priority string
---@field default_priority string
local PriorityState = {}

---@param priority string
function PriorityState:new(priority)
  local o = {}

  o.high_priority = tostring(config.org_priority_highest)
  o.low_priority = tostring(config.org_priority_lowest)
  o.default_priority = tostring(config.org_priority_default)
  o.priority = tostring(priority or o.default_priority)

  setmetatable(o, self)
  self.__index = self

  return o
end

---@return string|nil
function PriorityState:prompt_user()
  local prompt = string.format('Priority %s-%s, <Space> to remove: ', self.high_priority, self.low_priority)
  local choice = vim.fn.input(prompt)

  if choice == '' then
    utils.echo_warning(string.format("Priority must be between '%s' and '%s'", self.high_priority, self.low_priority))
    return nil
  end

  choice = string.upper(choice)
  if #choice > 1 and tonumber(choice) == nil then
    utils.echo_warning(string.format('Only numeric priorities can be multiple characters long'))
    return nil
  end
  local choicenum = string.byte(choice)
  if choice ~= ' ' and (choicenum < string.byte(self.high_priority) or choicenum > string.byte(self.low_priority)) then
    utils.echo_warning(string.format("Priority must be between '%s' and '%s'", self.high_priority, self.low_priority))
    return nil
  end

  return choice
end

---@return number
function PriorityState:get_sort_value()
  return -1 * string.byte(self.priority == '' and self.default_priority or self.priority)
end

---@return string
function PriorityState:increase()
  if self.priority == self.high_priority then
    self.priority = ''
  elseif self.priority == '' then
    self.priority = self.low_priority
  else
    self.priority = self:_apply(-1)
  end

  return self.priority
end

---@return string
function PriorityState:decrease()
  if self.priority == self.low_priority then
    self.priority = ''
  elseif self.priority == '' then
    self.priority = self.high_priority
  else
    self.priority = self:_apply(1)
  end

  return self.priority
end

---@param direction number
---@return string
function PriorityState:_apply(direction)
  if type(tonumber(self.priority)) == 'number' then
    return tostring(tonumber(self.priority) + direction)
  end
  return string.char(string.byte(self.priority) + direction)
end

return PriorityState

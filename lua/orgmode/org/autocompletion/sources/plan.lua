local config = require('orgmode.config')

---@class OrgCompletionPlan:OrgCompletionSource
---@field completion OrgCompletion
---@field private pattern vim.regex
local OrgCompletionPlan = {}
OrgCompletionPlan.__index = OrgCompletionPlan

---@param opts { completion: OrgCompletion }
function OrgCompletionPlan:new(opts)
  local this = setmetatable({
    pattern = vim.regex([[\(^\s*\|\s\+\)\zs\w*$]]),
    completion = opts.completion,
  }, OrgCompletionPlan)
  return this
end

function OrgCompletionPlan:get_name()
  return 'plan'
end

---@param context OrgCompletionContext
---@return number | nil
function OrgCompletionPlan:get_start(context)
  local prev_line = vim.fn.getline(vim.fn.line('.') - 1)
  if not self.completion:is_headline_line(prev_line) then
    return nil
  end

  return self.pattern:match_str(context.line)
end

---@return string[]
function OrgCompletionPlan:get_results(_)
  return {
    'DEADLINE:',
    'SCHEDULED:',
    'CLOSED:',
  }
end

return OrgCompletionPlan

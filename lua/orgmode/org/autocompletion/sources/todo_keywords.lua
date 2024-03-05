local config = require('orgmode.config')

---@class OrgCompletionTodoKeywords:OrgCompletionSource
---@field private pattern vim.regex
local OrgCompletionTodoKeywords = {}
OrgCompletionTodoKeywords.__index = OrgCompletionTodoKeywords

function OrgCompletionTodoKeywords:new()
  local this = setmetatable({
    pattern = vim.regex([[^\*\+\s\+\zs\w*$]]),
  }, OrgCompletionTodoKeywords)
  return this
end

function OrgCompletionTodoKeywords:get_name()
  return 'todo_keywords'
end

---@param context OrgCompletionContext
---@return number | nil
function OrgCompletionTodoKeywords:get_start(context)
  return self.pattern:match_str(context.line)
end

---@return string[]
function OrgCompletionTodoKeywords:get_results(_)
  return config:get_todo_keywords():all_values()
end

return OrgCompletionTodoKeywords

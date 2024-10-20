---@class OrgCompletionDirectives:OrgCompletionSource
---@field private pattern vim.regex
local OrgCompletionDirectives = {}
OrgCompletionDirectives.__index = OrgCompletionDirectives

function OrgCompletionDirectives:new()
  return setmetatable({
    pattern = vim.regex([[^\s*\zs\#+\?\w*$]]),
  }, OrgCompletionDirectives)
end

---@param context OrgCompletionContext
---@return number | nil
function OrgCompletionDirectives:get_start(context)
  return self.pattern:match_str(context.line)
end

function OrgCompletionDirectives:get_name()
  return 'directives'
end

---@return string[]
function OrgCompletionDirectives:get_results(_)
  return {
    '#+title',
    '#+author',
    '#+email',
    '#+name',
    '#+filetags',
    '#+archive',
    '#+options',
    '#+category',
    '#+begin_src',
    '#+begin_example',
    '#+end_src',
    '#+end_example',
  }
end

return OrgCompletionDirectives

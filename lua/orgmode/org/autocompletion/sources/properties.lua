---@class OrgCompletionProperties:OrgCompletionSource
---@field completion OrgCompletion
---@field private pattern vim.regex
local OrgCompletionProperties = {}
OrgCompletionProperties.__index = OrgCompletionProperties

---@param opts { completion: OrgCompletion }
function OrgCompletionProperties:new(opts)
  return setmetatable({
    completion = opts.completion,
    pattern = vim.regex([[^\s*\zs:\w*$]]),
  }, OrgCompletionProperties)
end

function OrgCompletionProperties:get_name()
  return 'properties'
end

---@param context OrgCompletionContext
---@return number | nil
function OrgCompletionProperties:get_start(context)
  if self.completion:is_headline_line(context.line) then
    return nil
  end

  return self.pattern:match_str(context.line)
end

---@return string[]
function OrgCompletionProperties:get_results(_)
  return {
    ':PROPERTIES:',
    ':END:',
    ':LOGBOOK:',
    ':STYLE:',
    ':REPEAT_TO_STATE:',
    ':CUSTOM_ID:',
    ':CATEGORY:',
  }
end

return OrgCompletionProperties

---@class OrgCompletionTags:OrgCompletionSource
---@field completion OrgCompletion
---@field private pattern vim.regex
---@field private filetags_pattern vim.regex
local OrgCompletionTags = {}
OrgCompletionTags.__index = OrgCompletionTags

---@param opts { completion: OrgCompletion }
function OrgCompletionTags:new(opts)
  return setmetatable({
    completion = opts.completion,
    filetags_pattern = vim.regex([[\c^\s*\#+filetags:\s\+]]),
    pattern = vim.regex([[:\([0-9A-Za-z_%@\#]*\)$]]),
  }, OrgCompletionTags)
end

function OrgCompletionTags:get_name()
  return 'tags'
end

---@param context OrgCompletionContext
---@return number | nil
function OrgCompletionTags:get_start(context)
  if not self.completion:is_headline_line(context.line) and not self.filetags_pattern:match_str(context.line) then
    return nil
  end
  return self.pattern:match_str(context.line)
end

---@return string[]
function OrgCompletionTags:get_results(_)
  return vim.tbl_map(function(tag)
    return table.concat({ ':', tag, ':' }, '')
  end, self.completion.files:get_tags())
end

return OrgCompletionTags

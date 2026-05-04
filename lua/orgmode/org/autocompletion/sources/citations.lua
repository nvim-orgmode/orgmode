---@class OrgCompletionCitations:OrgCompletionSource
---@field completion OrgCompletion
---@field private pattern vim.regex
local OrgCompletionCitations = {}
OrgCompletionCitations.__index = OrgCompletionCitations

---@param opts { completion: OrgCompletion }
function OrgCompletionCitations:new(opts)
  return setmetatable({
    completion = opts.completion,
    pattern = vim.regex([=[\[cite[/:][^\]]*@\zs[^ \]]*$]=]),
  }, OrgCompletionCitations)
end

---@return string
function OrgCompletionCitations:get_name()
  return 'citations'
end

---@param context OrgCompletionContext
---@return number | nil
function OrgCompletionCitations:get_start(context)
  return self.pattern:match_str(context.line)
end

---@param _ OrgCompletionContext
---@return string[]
function OrgCompletionCitations:get_results(_)
  local citations = self.completion.citations
  if not citations then
    return {}
  end
  local items = citations:get_items()
  return vim.tbl_map(function(item)
    return item.key
  end, items)
end

return OrgCompletionCitations

local Hyperlinks = require('orgmode.org.hyperlinks')
local Link = require('orgmode.org.hyperlinks.link')
---@class OrgCompletionHyperlinks:OrgCompletionSource
---@field completion OrgCompletion
---@field private pattern vim.regex
local OrgCompletionHyperlinks = {}
OrgCompletionHyperlinks.__index = OrgCompletionHyperlinks

---@param opts { completion: OrgCompletion }
function OrgCompletionHyperlinks:new(opts)
  return setmetatable({
    completion = opts.completion,
    pattern = vim.regex([[\s*\[\[\zs.*$]]),
  }, OrgCompletionHyperlinks)
end

function OrgCompletionHyperlinks:get_name()
  return 'hyperlinks'
end

---@param context OrgCompletionContext
---@return number | nil
function OrgCompletionHyperlinks:get_start(context)
  return self.pattern:match_str(context.line)
end

---@return string[]
function OrgCompletionHyperlinks:get_results(context)
  local link = Link:new(context.base)
  local result, mapper = Hyperlinks.find_matching_links(link.url)
  return mapper(result)
end

return OrgCompletionHyperlinks

---@meta

---@alias OrgCompletionContext { line: string, base?: string }
---@alias OrgCompletionItem { word: string, menu: string }

---@class OrgCompletionSource
---@field get_name fun(self: OrgCompletionSource): string
---@field get_start fun(self: OrgCompletionSource, context: OrgCompletionContext): number | nil
---@field get_results fun(self: OrgCompletionSource, context: OrgCompletionContext): string[]

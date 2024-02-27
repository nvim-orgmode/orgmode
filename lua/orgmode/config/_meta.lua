---@meta

---@alias OrgTodoKeywordType 'TODO'|'DONE'
---@alias OrgTodoKeyword string

---@class OrgTodoKeywords
---@field TODO OrgTodoKeyword[]
---@field DONE OrgTodoKeyword[]
---@field ALL OrgTodoKeyword[]
---@field KEYS table<OrgTodoKeyword, {type: OrgTodoKeywordType, shortcut: string, len: number, index: number}>
---@field FAST_ACCESS { value: OrgTodoKeyword, type: OrgTodoKeywordType, shortcut: string }[]
---@field has_fast_access boolean

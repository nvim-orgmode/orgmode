---@meta

---@class OrgLinkType
---@field get_name fun(self: OrgLinkType): string
---@field follow fun(self: OrgLinkType, link: string): boolean
---@field autocomplete fun(self: OrgLinkType, link: string): string[]

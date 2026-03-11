---@meta

---@class OrgCitationItem
---@field key string The citation key (e.g. "smith2020")
---@field label? string Optional display label used in completion menus
---@field description? string Optional human-readable description (author, title, year, etc.)

---@class OrgCitationSource
---@field get_name fun(self: OrgCitationSource): string Return the unique name of this source
---@field get_items fun(self: OrgCitationSource): OrgCitationItem[] Return all citation items
---@field follow? fun(self: OrgCitationSource, key: string): boolean Navigate to the entry for the given key; return true if handled

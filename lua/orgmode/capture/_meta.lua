---@meta

---@class OrgProcessRefileOpts
---@field source_headline OrgHeadline
---@field destination_file? OrgFile
---@field destination_headline? OrgHeadline
---@field lines? string[]
---@field message? string

---@class OrgProcessCaptureOpts
---@field template OrgCaptureTemplate
---@field source_file OrgFile
---@field source_headline? OrgHeadline
---@field destination_file OrgFile
---@field destination_headline? OrgHeadline

---@class OrgDatetreeTreeItem
---@field format string - The lua date format to use for the tree item
---@field pattern string - Pattern to match important date parts the date format
---@field order number[] - Order of checking the date parts matched from the pattern

---@class OrgCaptureTemplateDatetreeOpts
---@field date OrgDate
---@field time_prompt? boolean
---@field reversed? boolean
---@field tree? OrgDatetreeTreeItem[]
---@field tree_type? 'day' | 'week' | 'month' | 'custom'

---@alias OrgCaptureTemplateDatetree boolean | OrgCaptureTemplateDatetreeOpts

---@meta
---@alias OrgMarkupRange { line: number, start_col: number, end_col: number }

---@alias OrgMarkupParserType 'emphasis' | 'link' | 'latex' | 'date'

---@class OrgMarkupNode
---@field type OrgMarkupParserType
---@field char string
---@field id string
---@field seek_id string
---@field nestable boolean
---@field node TSNode
---@field range OrgMarkupRange
---@field self_contained? boolean
---@field metadata? table<string, any>

---@class OrgMarkupHighlight
---@field from OrgMarkupRange
---@field to OrgMarkupRange
---@field char string
---@field metadata? table<string, any>

---@class OrgMarkupPreparedHighlight
---@field start_line number
---@field start_col number
---@field end_col number
---@field hl_group string
---@field spell? boolean
---@field priority number
---@field conceal? boolean
---@field ephemeral boolean
---@field url? string

---@class OrgMarkupHighlighter
---@field parse_node fun(self: OrgMarkupHighlighter, node: TSNode, capture_name: string): OrgMarkupNode | false
---@field is_valid_start_node fun(self: OrgMarkupHighlighter, entry: OrgMarkupNode, bufnr: number): boolean
---@field is_valid_end_node fun(self: OrgMarkupHighlighter, entry: OrgMarkupNode, bufnr: number): boolean
---@field highlight fun(self: OrgMarkupHighlighter, highlights: OrgMarkupHighlight[], bufnr: number)
---@field prepare_highlights fun(self: OrgMarkupHighlighter, highlights: OrgMarkupHighlight[], source: number | string): OrgMarkupPreparedHighlight[]

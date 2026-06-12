local Range = require('orgmode.files.elements.range')
local ts_utils = require('orgmode.utils.treesitter')

---@class OrgFootnote
---@field label string
---@field range OrgRange
---@field is_reference boolean
local OrgFootnote = {}
OrgFootnote.__index = OrgFootnote

---@param label string
---@param range OrgRange
---@param is_reference boolean
---@return OrgFootnote
function OrgFootnote:new(label, range, is_reference)
  local this = setmetatable({}, { __index = OrgFootnote })
  this.label = label
  this.range = range
  this.is_reference = is_reference or false
  return this
end

function OrgFootnote:get_name()
  return self.label
end

---@param node TSNode | nil
---@param source? number | string
---@return OrgFootnote | nil
function OrgFootnote.from_node(node, source)
  local fnode = ts_utils.closest_node(ts_utils.get_node(), { 'fnref', 'fndef' })
  if not fnode then
    return nil
  end

  local text = vim.treesitter.get_node_text(fnode:field('label')[1], source or 0)
  return OrgFootnote:new(text, Range.from_node(node), fnode:type() == 'fnref')
end

---@return OrgFootnote | nil
function OrgFootnote.at_cursor()
  return OrgFootnote.from_node(ts_utils.get_node(), vim.api.nvim_get_current_buf())
end

return OrgFootnote

local OrgLinkUrl = require('orgmode.org.links.url')
local Range = require('orgmode.files.elements.range')
local ts_utils = require('orgmode.utils.treesitter')

---@class OrgHyperlink
---@field url OrgLinkUrl
---@field desc string | nil
---@field range? OrgRange
local OrgHyperlink = {}

---@param str string
---@param range? OrgRange
---@return OrgHyperlink
function OrgHyperlink:new(str, range)
  local this = setmetatable({}, { __index = OrgHyperlink })
  local parts = vim.split(str, '][', { plain = true })
  this.url = OrgLinkUrl:new(parts[1] or '')
  this.desc = parts[2]
  this.range = range
  return this
end

---Get hyperlink under current cursor position by parsing the line
---@return OrgHyperlink | nil
function OrgHyperlink.from_current_line_position()
  local pos = vim.fn.getpos('.')
  local line = vim.api.nvim_get_current_line()
  local start_pos = 0
  local end_pos = 0
  for i = pos[3], 1, -1 do
    if line:sub(i, i) == '[' and line:sub(i - 1, i - 1) == '[' then
      start_pos = i - 1
      break
    end
  end
  for i = pos[3], #line do
    if line:sub(i, i) == ']' and line:sub(i + 1, i + 1) == ']' then
      end_pos = i + 1
      break
    end
  end

  if start_pos == 0 or end_pos == 0 then
    return nil
  end
  local str = line:sub(start_pos + 2, end_pos - 2)
  return OrgHyperlink:new(
    str,
    Range:new({
      start_line = pos[2],
      start_col = start_pos,
      end_line = pos[2],
      end_col = end_pos,
    })
  )
end

---@param node TSNode
---@param source number | string
---@return OrgHyperlink
function OrgHyperlink.from_node(node, source)
  local url = node:field('url')[1]
  local desc = node:field('desc')[1]
  local this = setmetatable({}, { __index = OrgHyperlink })
  this.url = OrgLinkUrl:new(vim.treesitter.get_node_text(url, source))
  this.desc = desc and vim.treesitter.get_node_text(desc, source)
  this.range = Range.from_node(node)
  return this
end

---Get hyperlink under current cursor position by parsing the treesitter node
---@return OrgHyperlink | nil
function OrgHyperlink.at_cursor()
  local link_node = ts_utils.closest_node(ts_utils.get_node(), { 'link', 'link_desc' })
  if not link_node then
    return nil
  end
  return OrgHyperlink.from_node(link_node, vim.api.nvim_get_current_buf())
end

return OrgHyperlink

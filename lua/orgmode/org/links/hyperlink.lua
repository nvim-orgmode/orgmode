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

---Get hyperlink under current cursor position by parsing extmarks
---@return OrgHyperlink | nil
function OrgHyperlink.from_extmarks_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local inspect_pos = vim.inspect_pos(bufnr, nil, nil, {
    extmarks = true,
  })

  for _, extmark in ipairs(inspect_pos.extmarks) do
    if extmark.opts and extmark.opts.hl_group == '@org.hyperlink' then
      return OrgHyperlink:new(
        vim.api.nvim_buf_get_text(bufnr, extmark.row, extmark.col + 2, extmark.row, extmark.end_col - 2, {})[1],
        Range:new({
          start_line = extmark.row + 1,
          start_col = extmark.col + 1,
          end_line = extmark.row + 1,
          end_col = extmark.end_col,
        })
      )
    end
  end
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

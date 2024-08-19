local ts_utils = require('orgmode.utils.treesitter')

---@class OrgLinkHighlighter : OrgMarkupHighlighter
---@field private markup OrgMarkupHighlighter
local OrgLink = {}

---@param opts { markup: OrgMarkupHighlighter }
function OrgLink:new(opts)
  local data = {
    markup = opts.markup,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param node TSNode
---@return OrgMarkupNode | false
function OrgLink:parse_node(node)
  local type = node:type()
  if type == '[' then
    return self:_parse_start_node(node)
  end

  if type == ']' then
    return self:_parse_end_node(node)
  end

  return false
end

---@private
---@param node TSNode
---@return OrgMarkupNode | false
function OrgLink:_parse_start_node(node)
  local node_type = node:type()
  local next_sibling = node:next_sibling()

  if next_sibling and next_sibling:type() == '[' then
    local id = table.concat({ 'link', node_type }, '_')
    local seek_id = table.concat({ 'link', ']' }, '_')
    return {
      type = 'link',
      id = id,
      char = node_type,
      seek_id = seek_id,
      nestable = false,
      range = self.markup:node_to_range(node),
      node = node,
    }
  end

  return false
end

---@private
---@param node TSNode
---@return OrgMarkupNode | false
function OrgLink:_parse_end_node(node)
  local node_type = node:type()
  local prev_sibling = node:prev_sibling()
  if prev_sibling and prev_sibling:type() == ']' then
    local id = table.concat({ 'link', node_type }, '_')
    local seek_id = table.concat({ 'link', '[' }, '_')
    return {
      type = 'link',
      id = id,
      char = node_type,
      seek_id = seek_id,
      range = self.markup:node_to_range(node),
      nestable = false,
      node = node,
    }
  end

  return false
end

---@param entry OrgMarkupNode
---@return boolean
function OrgLink:is_valid_start_node(entry)
  return entry.type == 'link' and entry.id == 'link_['
end

---@param entry OrgMarkupNode
---@return boolean
function OrgLink:is_valid_end_node(entry)
  return entry.type == 'link' and entry.id == 'link_]'
end

---@param highlights OrgMarkupHighlight[]
---@param bufnr number
function OrgLink:highlight(highlights, bufnr)
  local namespace = self.markup.highlighter.namespace
  local ephemeral = self.markup:use_ephemeral()

  for _, entry in ipairs(highlights) do
    local link =
      vim.api.nvim_buf_get_text(bufnr, entry.from.line, entry.from.start_col, entry.from.line, entry.to.end_col, {})[1]
    local alias = link:find('%]%[') or 1
    local link_end = link:find('%]%[') or (link:len() - 1)

    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col, {
      ephemeral = ephemeral,
      end_col = entry.to.end_col,
      hl_group = '@org.hyperlink',
      priority = 110,
    })

    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col, {
      ephemeral = ephemeral,
      end_col = entry.from.start_col + 1 + alias,
      conceal = '',
    })

    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col + 2, {
      ephemeral = ephemeral,
      end_col = entry.from.start_col - 1 + link_end,
      spell = false,
    })

    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.to.end_col - 2, {
      ephemeral = ephemeral,
      end_col = entry.to.end_col,
      conceal = '',
    })
  end
end

return OrgLink

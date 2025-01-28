---@class OrgFootnotesHighlighter : OrgMarkupHighlighter
---@field private markup OrgMarkupHighlighter
local OrgFootnotes = {
  valid_capture_names = {
    ['footnote.start'] = true,
    ['footnote.end'] = true,
  },
}

---@param opts { markup: OrgMarkupHighlighter }
function OrgFootnotes:new(opts)
  local data = {
    markup = opts.markup,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param node TSNode
---@param name string
---@return OrgMarkupNode | false
function OrgFootnotes:parse_node(node, name)
  if not self.valid_capture_names[name] then
    return false
  end
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
function OrgFootnotes:_parse_start_node(node)
  local node_type = node:type()
  local first_sibling = node:next_sibling()
  local second_sibling = first_sibling and first_sibling:next_sibling()

  if not first_sibling or not second_sibling then
    return false
  end
  if first_sibling:type() ~= 'str' or second_sibling:type() ~= ':' then
    return false
  end

  return {
    type = 'footnote',
    id = 'footnote_start',
    char = node_type,
    seek_id = 'footnote_end',
    nestable = false,
    range = self.markup:node_to_range(node),
    node = node,
  }
end

---@private
---@param node TSNode
---@return OrgMarkupNode | false
function OrgFootnotes:_parse_end_node(node)
  local node_type = node:type()
  local prev_sibling = node:prev_sibling()

  if not prev_sibling then
    return false
  end

  return {
    type = 'footnote',
    id = 'footnote_end',
    seek_id = 'footnote_start',
    char = node_type,
    nestable = false,
    range = self.markup:node_to_range(node),
    node = node,
  }
end

---@param entry OrgMarkupNode
---@return boolean
function OrgFootnotes:is_valid_start_node(entry)
  return entry.type == 'footnote' and entry.id == 'footnote_start'
end

---@param entry OrgMarkupNode
---@return boolean
function OrgFootnotes:is_valid_end_node(entry)
  return entry.type == 'footnote' and entry.id == 'footnote_end'
end

---@param highlights OrgMarkupHighlight[]
---@param bufnr number
function OrgFootnotes:highlight(highlights, bufnr)
  local namespace = self.markup.highlighter.namespace
  local ephemeral = self.markup:use_ephemeral()

  for _, entry in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col, {
      ephemeral = ephemeral,
      end_col = entry.to.end_col,
      hl_group = '@org.footnote',
      priority = 110,
    })
  end
end

---@param highlights OrgMarkupHighlight[]
---@return OrgMarkupPreparedHighlight[]
function OrgFootnotes:prepare_highlights(highlights)
  local ephemeral = self.markup:use_ephemeral()
  local extmarks = {}
  for _, entry in ipairs(highlights) do
    table.insert(extmarks, {
      start_line = entry.from.line,
      start_col = entry.from.start_col,
      end_col = entry.to.end_col,
      ephemeral = ephemeral,
      hl_group = '@org.footnote',
      priority = 110,
    })
  end
  return extmarks
end

return OrgFootnotes

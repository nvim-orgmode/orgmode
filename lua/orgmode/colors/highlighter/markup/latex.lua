---@class OrgLatexHighlighter : OrgMarkupHighlighter
---@field private markup OrgMarkupHighlighter
local OrgLatex = {
  valid_capture_names = {
    ['latex.plain'] = true,
    ['latex.bracket.start'] = true,
    ['latex.bracket.end'] = true,
    ['latex.curly.start'] = true,
    ['latex.curly.end'] = true,
    ['latex.square.start'] = true,
    ['latex.square.end'] = true,
  },
}

local latex_pairs = {
  ['('] = ')',
  [')'] = '(',
  ['{'] = '}',
  ['}'] = '{',
  ['['] = ']',
  [']'] = '[',
}

local valid_start_ids = {
  ['latex_('] = true,
  ['latex_{'] = true,
  ['latex_['] = true,
}

local valid_end_ids = {
  ['latex_)'] = true,
  ['latex_}'] = true,
  ['latex_]'] = true,
  ['latex_str'] = true,
}

---@param opts { markup: OrgMarkupHighlighter }
function OrgLatex:new(opts)
  local data = {
    markup = opts.markup,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param entry OrgMarkupNode
---@return boolean
function OrgLatex:is_valid_start_node(entry)
  return entry.type == 'latex' and valid_start_ids[entry.id]
end

---@param entry OrgMarkupNode
---@return boolean
function OrgLatex:is_valid_end_node(entry)
  return entry.type == 'latex' and valid_end_ids[entry.id]
end

---@param node TSNode
---@return OrgMarkupNode | false
function OrgLatex:parse_node(node, name)
  if not self.valid_capture_names[name] then
    return false
  end
  local node_type = node:type()
  if node_type ~= 'str' and not latex_pairs[node_type] then
    return false
  end
  local prev_sibling = node:prev_sibling()

  if not prev_sibling or prev_sibling:type() ~= '\\' then
    return false
  end

  local is_self_contained = node_type == 'str'

  local id = table.concat({ 'latex', node_type }, '_')
  local seek_id = table.concat({ 'latex', latex_pairs[node_type] or 'str' }, '_')

  local info = {
    type = 'latex',
    char = node_type,
    id = id,
    seek_id = seek_id,
    nestable = false,
    self_contained = is_self_contained,
    range = self.markup:node_to_range(node),
    node = node,
  }

  if is_self_contained then
    local next_sibling = node:next_sibling()
    while next_sibling and latex_pairs[next_sibling:type()] do
      info.range.end_col = info.range.end_col + 1
      next_sibling = next_sibling:next_sibling()
    end
  end

  return info
end

---@param highlights OrgMarkupHighlight[]
---@param bufnr number
function OrgLatex:highlight(highlights, bufnr)
  local ephemeral = self.markup:use_ephemeral()
  local namespace = self.markup.highlighter.namespace
  for _, entry in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col - 1, {
      ephemeral = ephemeral,
      end_col = entry.to.end_col,
      hl_group = '@org.latex',
      spell = false,
      priority = 110 + entry.from.start_col,
    })
  end
end

---@param highlights OrgMarkupHighlight[]
---@return OrgMarkupPreparedHighlight[]
function OrgLatex:prepare_highlights(highlights)
  local ephemeral = self.markup:use_ephemeral()
  local extmarks = {}
  for _, entry in ipairs(highlights) do
    table.insert(extmarks, {
      start_line = entry.from.line,
      start_col = entry.from.start_col,
      end_col = entry.to.end_col,
      ephemeral = ephemeral,
      hl_group = '@org.latex',
      spell = false,
      priority = 110 + entry.from.start_col,
    })
  end
  return extmarks
end

return OrgLatex

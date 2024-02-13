local ts_utils = require('orgmode.utils.treesitter')

---@class OrgLatexHighlighter : OrgMarkupHighlighter
---@field private markup OrgMarkupHighlighter
local OrgLatex = {}

local latex_pairs = {
  ['('] = ')',
  [')'] = '(',
  ['{'] = '}',
  ['}'] = '{',
  ['['] = ']',
  [']'] = '[',
}

---@param opts { markup: OrgMarkupHighlighter }
function OrgLatex:new(opts)
  local data = {
    markup = opts.markup,
  }
  setmetatable(data, self)
  self.__index = self
  data:_add_hl_groups()
  return data
end

---@param entry OrgMarkupNode
---@return boolean
function OrgLatex:is_valid_start_node(entry)
  local valid_start_chars = {
    ['('] = true,
    ['{'] = true,
    ['['] = true,
  }
  return entry.type == 'latex' and valid_start_chars[entry.char]
end

---@param entry OrgMarkupNode
---@return boolean
function OrgLatex:is_valid_end_node(entry)
  local valid_end_chars = {
    [')'] = true,
    ['}'] = true,
    [']'] = true,
    str = true,
  }
  return entry.type == 'latex' and valid_end_chars[entry.char]
end

---@param node TSNode
---@return OrgMarkupNode | false
function OrgLatex:parse_node(node)
  local type = node:type()
  if type ~= 'str' and not latex_pairs[type] then
    return false
  end
  local prev_sibling = node:prev_sibling()

  if not prev_sibling or prev_sibling:type() ~= '\\' then
    return false
  end

  local is_self_contained = type == 'str'

  local info = {
    type = 'latex',
    char = type,
    seek_char = latex_pairs[type] or 'str',
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

function OrgLatex:_add_hl_groups()
  vim.cmd('hi def link org_latex OrgTSLatex')
end

---@param highlights OrgMarkupHighlight[]
---@param bufnr number
function OrgLatex:highlight(highlights, bufnr)
  local namespace = self.markup.highlighter.namespace
  for _, entry in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col - 1, {
      ephemeral = true,
      end_col = entry.to.end_col,
      hl_group = 'org_latex',
      spell = false,
      priority = 110 + entry.from.start_col,
    })
  end
end

return OrgLatex

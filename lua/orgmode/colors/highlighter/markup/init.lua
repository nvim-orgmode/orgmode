---@class OrgMarkupHighlighter
---@field highlighter OrgHighlighter
---@field private cache table
---@field private query vim.treesitter.Query
---@field private parsers { emphasis: OrgEmphasisHighlighter, link: OrgLinkHighlighter, latex: OrgLatexHighlighter }
local OrgMarkup = {}

---@param opts { highlighter: OrgHighlighter }
function OrgMarkup:new(opts)
  local data = {
    highlighter = opts.highlighter,
    cache = setmetatable({}, { __mode = 'k' }),
    query = vim.treesitter.query.get('org', 'markup'),
  }
  setmetatable(data, self)
  self.__index = self
  data:_init_highlighters()
  return data
end

---@private
function OrgMarkup:_init_highlighters()
  self.parsers = {
    emphasis = require('orgmode.colors.highlighter.markup.emphasis'):new({ markup = self }),
    footnote = require('orgmode.colors.highlighter.markup.footnotes'):new({ markup = self }),
    latex = require('orgmode.colors.highlighter.markup.latex'):new({ markup = self }),
  }
end

---@param bufnr number
---@param line number
---@param tree TSTree
function OrgMarkup:on_line(bufnr, line, tree)
  local highlights = self:_get_highlights(bufnr, line, tree)

  for type, highlight in pairs(highlights) do
    self.parsers[type]:highlight(highlight, bufnr)
  end
end

---@param bufnr number
---@param line number
---@param tree TSTree
---@return { emphasis: OrgMarkupHighlight[], link: OrgMarkupHighlight[], latex: OrgMarkupHighlight[], date: OrgMarkupHighlight[] }
function OrgMarkup:_get_highlights(bufnr, line, tree)
  local line_content = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1]

  if self.cache[bufnr] and self.cache[bufnr][line] and self.cache[bufnr][line].line_content == line_content then
    return self.cache[bufnr][line].highlights
  end

  local result = self:get_node_highlights(tree:root(), bufnr, line)

  if not self.cache[bufnr] then
    self.cache[bufnr] = {}
  end

  self.cache[bufnr][line] = {
    line_content = line_content,
    highlights = result,
  }

  return result
end

---@param root_node TSNode
---@param source number | string
---@param line number
---@return { emphasis: OrgMarkupHighlight[], link: OrgMarkupHighlight[], latex: OrgMarkupHighlight[], date: OrgMarkupHighlight[] }
function OrgMarkup:get_node_highlights(root_node, source, line)
  local result = {
    emphasis = {},
    latex = {},
    footnote = {},
  }
  ---@type OrgMarkupNode[]
  local entries = {}

  for capture_id, node in self.query:iter_captures(root_node, source, line, line + 1) do
    local entry = nil
    for _, parser in pairs(self.parsers) do
      entry = parser:parse_node(node, self.query.captures[capture_id])
      if entry then
        table.insert(entries, entry)
        break
      end
    end
  end

  if #entries == 0 then
    return result
  end

  ---@type table<string, OrgMarkupNode>
  local seek = {}
  local last_seek = nil

  local is_valid_start_item = function(item)
    if last_seek and not last_seek.nestable then
      return false
    end
    if not self:has_valid_parent(item) then
      return false
    end
    return self.parsers[item.type]:is_valid_start_node(item, source)
  end

  local is_valid_end_item = function(item)
    if not self:has_valid_parent(item) then
      return false
    end

    return self.parsers[item.type]:is_valid_end_node(item, source)
  end

  for _, item in ipairs(entries) do
    local from = seek[item.seek_id]

    if not from and not item.self_contained then
      if is_valid_start_item(item) then
        seek[item.id] = item
        last_seek = item
      end
      goto continue
    end

    if is_valid_end_item(item) then
      table.insert(result[item.type], {
        id = item.id,
        char = item.char,
        from = item.self_contained and item.range or from.range,
        to = item.range,
        metadata = item.metadata,
      })

      if last_seek and last_seek.type == item.type then
        last_seek = nil
      end
    end

    if item.self_contained then
      goto continue
    end

    seek[item.seek_id] = nil
    for t, pos in pairs(seek) do
      if
        pos.range.line == from.range.line
        and pos.range.start_col > from.range.end_col
        and pos.range.start_col < item.range.start_col
      then
        seek[t] = nil
      end
    end

    ::continue::
  end

  return result
end

---@param headline OrgHeadline
---@return OrgMarkupPreparedHighlight[]
function OrgMarkup:get_prepared_headline_highlights(headline)
  local highlights =
    self:get_node_highlights(headline:node(), headline.file:get_source(), select(1, headline:node():range()))

  local result = {}

  for type, highlight in pairs(highlights) do
    vim.list_extend(
      result,
      self.parsers[type]:prepare_highlights(highlight, function(start_col, end_col)
        local text = headline.file:get_node_text(headline:node())
        return text:sub(start_col, end_col)
      end)
    )
  end

  return result
end

function OrgMarkup:on_detach(bufnr)
  self.cache[bufnr] = nil
end

---@param node TSNode
---@param source number | string
---@param offset_col_start? number
---@param offset_col_end? number
---@return string
function OrgMarkup:get_node_text(node, source, offset_col_start, offset_col_end)
  local range = { node:range() }
  return vim.treesitter.get_node_text(node, source, {
    metadata = {
      range = {
        range[1],
        math.max(0, range[2] + (offset_col_start or 0)),
        range[3],
        math.max(0, range[4] + (offset_col_end or 0)),
      },
    },
  })
end

function OrgMarkup:node_to_range(node)
  local start_row, start_col, _, end_col = node:range()
  return {
    line = start_row,
    start_col = start_col,
    end_col = end_col,
  }
end

---@param item OrgMarkupNode
---@return boolean
function OrgMarkup:has_valid_parent(item)
  -- expr
  local parent = item.node:parent()
  if not parent then
    return false
  end

  parent = parent:parent()
  if not parent then
    return false
  end

  if parent:type() == 'paragraph' or parent:type() == 'link_desc' then
    return true
  end

  local p = parent:parent()

  if parent:type() == 'item' and p then
    return p:type() == 'headline'
  end

  if parent:type() == 'contents' and p then
    return p:type() == 'drawer' or p:type() == 'cell'
  end

  if parent:type() == 'description' and p and p:type() == 'fndef' then
    return true
  end

  if parent:type() == 'value' then
    return p and p:type() == 'property' or false
  end

  return false
end

function OrgMarkup:use_ephemeral()
  ---@diagnostic disable-next-line: invisible
  return self.highlighter._ephemeral
end

function OrgMarkup:get_links_for_line(bufnr, line)
  local cache = self.cache[bufnr]
  if not cache or not cache[line] then
    return
  end
  return cache[line].highlights.link
end

return OrgMarkup

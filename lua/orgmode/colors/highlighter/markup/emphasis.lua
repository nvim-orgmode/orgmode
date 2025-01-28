local config = require('orgmode.config')
local ts_utils = require('orgmode.utils.treesitter')

---@class OrgEmphasisHighlighter : OrgMarkupHighlighter
---@field private markup OrgMarkupHighlighter
local OrgEmphasis = {
  valid_capture_names = {
    ['bold'] = true,
    ['italic'] = true,
    ['underline'] = true,
    ['strikethrough'] = true,
    ['code'] = true,
    ['verbatim'] = true,
  },
}

local valid_pre_marker_chars = { ' ', '(', '-', "'", '"', '{', '*', '/', '_', '+' }
local valid_post_marker_chars =
  { ' ', ')', '-', '}', '"', "'", ':', ';', '!', '\\', '[', ',', '.', '?', '*', '/', '_', '+' }

local markers = {
  ['*'] = {
    hl_name = '@org.bold',
    nestable = true,
  },
  ['/'] = {
    hl_name = '@org.italic',
    nestable = true,
  },
  ['_'] = {
    hl_name = '@org.underline',
    nestable = true,
  },
  ['+'] = {
    hl_name = '@org.strikethrough',
    nestable = true,
  },
  ['~'] = {
    hl_name = '@org.code',
    nestable = false,
    spell = false,
  },
  ['='] = {
    hl_name = '@org.verbatim',
    nestable = false,
    spell = false,
  },
}

---@param opts { markup: OrgMarkupHighlighter }
function OrgEmphasis:new(opts)
  local data = {
    markup = opts.markup,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param highlights OrgMarkupHighlight[]
---@param bufnr number
function OrgEmphasis:highlight(highlights, bufnr)
  local namespace = self.markup.highlighter.namespace
  local hide_markers = config.org_hide_emphasis_markers
  local ephemeral = self.markup:use_ephemeral()
  local conceal = hide_markers and '' or nil

  for _, entry in ipairs(highlights) do
    -- Leading delimiter
    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col, {
      ephemeral = ephemeral,
      end_col = entry.from.end_col,
      hl_group = markers[entry.char].hl_name .. '.delimiter',
      spell = markers[entry.char].spell,
      priority = 110 + entry.from.start_col,
      conceal = conceal,
    })

    -- Closing delimiter
    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.to.start_col, {
      ephemeral = ephemeral,
      end_col = entry.to.end_col,
      hl_group = markers[entry.char].hl_name .. '.delimiter',
      spell = markers[entry.char].spell,
      priority = 110 + entry.from.start_col,
      conceal = conceal,
    })

    -- Main body highlight
    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col + 1, {
      ephemeral = ephemeral,
      end_col = entry.to.end_col - 1,
      hl_group = markers[entry.char].hl_name,
      spell = markers[entry.char].spell,
      priority = 110 + entry.from.start_col,
    })
  end
end

---@param highlights OrgMarkupHighlight[]
---@return OrgMarkupPreparedHighlight[]
function OrgEmphasis:prepare_highlights(highlights)
  local hide_markers = config.org_hide_emphasis_markers
  local ephemeral = self.markup:use_ephemeral()
  local conceal = hide_markers and '' or nil
  local extmarks = {}

  for _, entry in ipairs(highlights) do
    -- Leading delimiter
    table.insert(extmarks, {
      start_line = entry.from.line,
      start_col = entry.from.start_col,
      end_col = entry.from.end_col,
      ephemeral = ephemeral,
      hl_group = markers[entry.char].hl_name .. '.delimiter',
      spell = markers[entry.char].spell,
      priority = 110 + entry.from.start_col,
      conceal = conceal,
    })

    -- Closing delimiter
    table.insert(extmarks, {
      start_line = entry.from.line,
      start_col = entry.to.start_col,
      ephemeral = ephemeral,
      end_col = entry.to.end_col,
      hl_group = markers[entry.char].hl_name .. '.delimiter',
      spell = markers[entry.char].spell,
      priority = 110 + entry.from.start_col,
      conceal = conceal,
    })

    -- Main body highlight
    table.insert(extmarks, {
      start_line = entry.from.line,
      start_col = entry.from.start_col + 1,
      ephemeral = ephemeral,
      end_col = entry.to.end_col - 1,
      hl_group = markers[entry.char].hl_name,
      spell = markers[entry.char].spell,
      priority = 110 + entry.from.start_col,
    })
  end

  return extmarks
end

---@param node TSNode
---@param name string
---@return OrgMarkupNode | false
function OrgEmphasis:parse_node(node, name)
  if not self.valid_capture_names[name] then
    return false
  end
  local node_type = node:type()
  if not markers[node_type] then
    return false
  end
  local prev_node = node:prev_sibling()
  local next_node = node:next_sibling()

  if prev_node and prev_node:type() == node_type then
    return false
  end

  if next_node and next_node:type() == node_type then
    return false
  end

  local id = table.concat({ 'emphasis', node_type }, '_')

  return {
    type = 'emphasis',
    char = node_type,
    id = id,
    seek_id = id,
    nestable = markers[node_type].nestable,
    range = self.markup:node_to_range(node),
    node = node,
  }
end

---@param entry OrgMarkupNode
---@param source number | string
---@return boolean
function OrgEmphasis:is_valid_start_node(entry, source)
  local start_text = self.markup:get_node_text(entry.node, source, -1, 1)
  local start_len = start_text:len()

  return (start_len < 3 or vim.tbl_contains(valid_pre_marker_chars, start_text:sub(1, 1)))
    and start_text:sub(start_len, start_len) ~= ' '
end

---@param entry OrgMarkupNode
---@param source number | string
---@return boolean
function OrgEmphasis:is_valid_end_node(entry, source)
  local end_text = self.markup:get_node_text(entry.node, source, -1, 1)
  return (end_text:len() < 3 or vim.tbl_contains(valid_post_marker_chars, end_text:sub(3, 3)))
    and end_text:sub(1, 1) ~= ' '
end

return OrgEmphasis

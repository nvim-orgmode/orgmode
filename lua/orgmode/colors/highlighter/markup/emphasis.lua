local config = require('orgmode.config')
local ts_utils = require('orgmode.utils.treesitter')

---@class OrgEmphasisHighlighter : OrgMarkupHighlighter
---@field private markup OrgMarkupHighlighter
local OrgEmphasis = {}

local valid_pre_marker_chars = { ' ', '(', '-', "'", '"', '{', '*', '/', '_', '+' }
local valid_post_marker_chars =
  { ' ', ')', '-', '}', '"', "'", ':', ';', '!', '\\', '[', ',', '.', '?', '*', '/', '_', '+' }

local markers = {
  ['*'] = {
    hl_name = 'org_bold',
    hl_cmd = 'hi def %s term=bold cterm=bold gui=bold',
    nestable = true,
  },
  ['/'] = {
    hl_name = 'org_italic',
    hl_cmd = 'hi def %s term=italic cterm=italic gui=italic',
    nestable = true,
  },
  ['_'] = {
    hl_name = 'org_underline',
    hl_cmd = 'hi def %s term=underline cterm=underline gui=underline',
    nestable = true,
  },
  ['+'] = {
    hl_name = 'org_strikethrough',
    hl_cmd = 'hi def %s term=strikethrough cterm=strikethrough gui=strikethrough',
    nestable = true,
  },
  ['~'] = {
    hl_name = 'org_code',
    hl_cmd = 'hi def link %s String',
    nestable = false,
    spell = false,
  },
  ['='] = {
    hl_name = 'org_verbatim',
    hl_cmd = 'hi def link %s String',
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
  data:_add_hl_groups()
  return data
end

---@param highlights OrgMarkupHighlight[]
---@param bufnr number
function OrgEmphasis:highlight(highlights, bufnr)
  local namespace = self.markup.highlighter.namespace
  local hide_markers = config.org_hide_emphasis_markers

  for _, entry in ipairs(highlights) do
    local hl_offset = 1

    -- Leading delimiter
    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col, {
      ephemeral = true,
      end_col = entry.from.start_col + hl_offset,
      hl_group = markers[entry.type].hl_name .. '_delimiter',
      spell = markers[entry.type].spell,
      priority = 110 + entry.from.start_col,
    })

    -- Closing delimiter
    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.to.end_col - hl_offset, {
      ephemeral = true,
      end_col = entry.to.end_col,
      hl_group = markers[entry.type].hl_name .. '_delimiter',
      spell = markers[entry.type].spell,
      priority = 110 + entry.from.start_col,
    })

    -- Main body highlight
    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col + hl_offset, {
      ephemeral = true,
      end_col = entry.to.end_col - hl_offset,
      hl_group = markers[entry.type].hl_name,
      spell = markers[entry.type].spell,
      priority = 110 + entry.from.start_col,
    })

    if hide_markers then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.line, entry.from.start_col, {
        end_col = entry.from.end_col,
        ephemeral = true,
        conceal = '',
      })
      vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.to.line, entry.to.start_col, {
        end_col = entry.to.end_col,
        ephemeral = true,
        conceal = '',
      })
    end
  end
end

---@param node TSNode
---@return OrgMarkupNode | false
function OrgEmphasis:parse_node(node)
  local type = node:type()
  if not markers[type] then
    return false
  end

  return {
    type = 'emphasis',
    char = type,
    seek_char = type,
    nestable = markers[type].nestable,
    range = self.markup:node_to_range(node),
    node = node,
  }
end

---@param entry OrgMarkupNode
---@param bufnr number
---@return boolean
function OrgEmphasis:is_valid_start_node(entry, bufnr)
  local start_text = self.markup:get_node_text(entry.node, bufnr, -1, 1)
  local start_len = start_text:len()

  return (start_len < 3 or vim.tbl_contains(valid_pre_marker_chars, start_text:sub(1, 1)))
    and start_text:sub(start_len, start_len) ~= ' '
end

---@param entry OrgMarkupNode
---@param bufnr number
---@return boolean
function OrgEmphasis:is_valid_end_node(entry, bufnr)
  local end_text = self.markup:get_node_text(entry.node, bufnr, -1, 1)
  return (end_text:len() < 3 or vim.tbl_contains(valid_post_marker_chars, end_text:sub(3, 3)))
    and end_text:sub(1, 1) ~= ' '
end

function OrgEmphasis:_add_hl_groups()
  for _, marker in pairs(markers) do
    vim.cmd(string.format(marker.hl_cmd, marker.hl_name))
    if marker.delimiter_hl then
      vim.cmd(string.format(marker.hl_cmd, marker.hl_name .. '_delimiter'))
    end
  end
  vim.cmd('hi def link org_hyperlink Underlined')
end

return OrgEmphasis

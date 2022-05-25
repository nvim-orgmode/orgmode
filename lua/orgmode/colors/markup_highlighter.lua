local config = require('orgmode.config')
local ts_utils = require('nvim-treesitter.ts_utils')
local query = nil

local valid_pre_marker_chars = { ' ', '(', '-', "'", '"', '{' }
local valid_post_marker_chars = { ' ', ')', '-', '}', '"', "'", ':', ';', '!', '\\', '[', ',', '.', '?' }

local markers = {
  ['*'] = {
    hl_name = 'org_bold',
    hl_cmd = 'hi def org_bold term=bold cterm=bold gui=bold',
  },
  ['/'] = {
    hl_name = 'org_italic',
    hl_cmd = 'hi def org_italic term=italic cterm=italic gui=italic',
  },
  ['_'] = {
    hl_name = 'org_underline',
    hl_cmd = 'hi def org_underline term=underline cterm=underline gui=underline',
  },
  ['+'] = {
    hl_name = 'org_strikethrough',
    hl_cmd = 'hi def org_strikethrough term=strikethrough cterm=strikethrough gui=strikethrough',
  },
  ['~'] = {
    hl_name = 'org_code',
    hl_cmd = 'hi def link org_code String',
  },
  ['='] = {
    hl_name = 'org_verbatim',
    hl_cmd = 'hi def link org_verbatim String',
  },
}

local function get_node_text(node, source, offset_col_start, offset_col_end)
  local start_row, start_col = node:start()
  local end_row, end_col = node:end_()
  start_col = start_col + (offset_col_start or 0)
  end_col = end_col + (offset_col_end or 0)

  local lines
  local eof_row = vim.api.nvim_buf_line_count(source)
  if start_row >= eof_row then
    return nil
  end

  if end_col == 0 then
    lines = vim.api.nvim_buf_get_lines(source, start_row, end_row, true)
    end_col = -1
  else
    lines = vim.api.nvim_buf_get_lines(source, start_row, end_row + 1, true)
  end

  if #lines > 0 then
    if #lines == 1 then
      lines[1] = string.sub(lines[1], start_col + 1, end_col)
    else
      lines[1] = string.sub(lines[1], start_col + 1)
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
  end

  return table.concat(lines, '\n')
end

local get_tree = ts_utils.memoize_by_buf_tick(function(bufnr)
  local tree = vim.treesitter.get_parser(bufnr, 'org'):parse()
  if not tree or not #tree then
    return nil
  end
  return tree[1]:root()
end)

local function get_predicate_nodes(match)
  local counter = 1
  local start_node = nil
  local end_node = nil
  for i, node in pairs(match) do
    if counter == 1 then
      start_node = node
    end
    if counter == 2 then
      end_node = node
    end
    counter = counter + 1
  end
  if not start_node or not end_node then
    return false
  end
  return start_node, end_node
end

local function is_valid_markup_range(match, _, source, _)
  local start_node, end_node = get_predicate_nodes(match)
  if not start_node or not end_node then
    return
  end

  -- Ignore conflicts with hyperlink
  if start_node:type() == '[' or end_node:type() == ']' then
    return true
  end

  local start_line = start_node:range()
  local end_line = start_node:range()

  if start_line ~= end_line then
    return false
  end

  local start_text = get_node_text(start_node, source, -1, 1)
  local start_len = start_text:len()

  local is_valid_start = (start_len < 3 or vim.tbl_contains(valid_pre_marker_chars, start_text:sub(1, 1)))
    and start_text:sub(start_len, start_len) ~= ' '
  if not is_valid_start then
    return false
  end
  local end_text = get_node_text(end_node, source, -1, 1)
  return (end_text:len() < 3 or vim.tbl_contains(valid_post_marker_chars, end_text:sub(3, 3)))
    and end_text:sub(1, 1) ~= ' '
end

local function is_valid_hyperlink_range(match, _, source, _)
  local start_node, end_node = get_predicate_nodes(match)
  if not start_node or not end_node then
    return
  end
  -- Ignore conflicts with markup
  if start_node:type() ~= '[' or end_node:type() ~= ']' then
    return true
  end

  local start_line = start_node:range()
  local end_line = start_node:range()

  if start_line ~= end_line then
    return false
  end

  local start_text = get_node_text(start_node, source, 0, 1)
  local end_text = get_node_text(end_node, source, -1)

  local is_valid_start = start_text == '[['
  local is_valid_end = end_text == ']]'
  return is_valid_start and is_valid_end
end

local function load_deps()
  -- Already defined
  if query then
    return
  end
  query = vim.treesitter.get_query('org', 'markup')
  vim.treesitter.query.add_predicate('org-is-valid-markup-range?', is_valid_markup_range)
  vim.treesitter.query.add_predicate('org-is-valid-hyperlink-range?', is_valid_hyperlink_range)
end

---@param bufnr? number
---@param first_line? number
---@param last_line? number
---@return table[]
local function get_matches(bufnr, first_line, last_line)
  bufnr = bufnr or 0
  local root = get_tree(bufnr)
  if not root then
    return
  end

  local ranges = {}
  local taken_locations = {}

  for _, match, _ in query:iter_matches(root, bufnr, first_line, last_line) do
    for _, node in pairs(match) do
      local char = node:type()
      local range = ts_utils.node_to_lsp_range(node)
      local linenr = tostring(range.start.line)
      taken_locations[linenr] = taken_locations[linenr] or {}
      if not taken_locations[linenr][range.start.character] then
        table.insert(ranges, {
          type = char,
          range = range,
        })
        taken_locations[linenr][range.start.character] = true
      end
    end
  end

  table.sort(ranges, function(a, b)
    if a.range.start.line == b.range.start.line then
      return a.range.start.character < b.range.start.character
    end
    return a.range.start.line < b.range.start.line
  end)

  local seek = {}
  local seek_link = {}
  local result = {}
  local link_result = {}

  for _, item in ipairs(ranges) do
    if markers[item.type] then
      if seek[item.type] then
        local from = seek[item.type]
        table.insert(result, {
          type = item.type,
          from = from.range,
          to = item.range,
        })

        seek[item.type] = nil

        for t, pos in pairs(seek) do
          if
            pos.range.start.line == from.range.start.line
            and pos.range.start.character > from.range['end'].character
            and pos.range.start.character < item.range.start.character
          then
            seek[t] = nil
          end
        end
      else
        seek[item.type] = item
      end
    end

    if item.type == '[' then
      seek_link = item
    end

    if item.type == ']' and seek_link then
      table.insert(link_result, {
        from = seek_link.range,
        to = item.range,
      })
      seek_link = nil
    end
  end

  return result, link_result
end

local function apply(namespace, bufnr, _, first_line, last_line, _)
  local visible_lines = {}
  -- Add some offset to make sure everything is covered
  local start_line = math.max(0, first_line - 5)
  for i = start_line, last_line do
    if vim.fn.foldclosed(i + 1) == -1 then
      table.insert(visible_lines, i)
    end
  end
  if #visible_lines == 0 then
    return
  end
  local ranges, link_ranges = get_matches(bufnr, visible_lines[1], visible_lines[#visible_lines])
  local hide_markers = config.org_hide_emphasis_markers

  for _, range in ipairs(ranges) do
    vim.api.nvim_buf_set_extmark(bufnr, namespace, range.from.start.line, range.from.start.character, {
      ephemeral = true,
      end_col = range.to['end'].character,
      hl_group = markers[range.type].hl_name,
      priority = 110 + range.from.start.character,
    })

    if hide_markers then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, range.from.start.line, range.from.start.character, {
        end_col = range.from['end'].character,
        ephemeral = true,
        conceal = '',
      })
      vim.api.nvim_buf_set_extmark(bufnr, namespace, range.to.start.line, range.to.start.character, {
        end_col = range.to['end'].character,
        ephemeral = true,
        conceal = '',
      })
    end
  end

  for _, link_range in ipairs(link_ranges) do
    local line = vim.api.nvim_buf_get_lines(bufnr, link_range.from.start.line, link_range.from.start.line + 1, false)[1]
    local link = line:sub(link_range.from.start.character + 1, link_range.to['end'].character)
    local alias = link:find('%]%[') or 1

    vim.api.nvim_buf_set_extmark(bufnr, namespace, link_range.from.start.line, link_range.from.start.character, {
      ephemeral = true,
      end_col = link_range.to['end'].character,
      hl_group = 'org_hyperlink',
      priority = 110,
    })

    vim.api.nvim_buf_set_extmark(bufnr, namespace, link_range.from.start.line, link_range.from.start.character, {
      ephemeral = true,
      end_col = link_range.from.start.character + 1 + alias,
      conceal = '',
    })

    vim.api.nvim_buf_set_extmark(bufnr, namespace, link_range.from.start.line, link_range.to['end'].character - 2, {
      ephemeral = true,
      end_col = link_range.to['end'].character,
      conceal = '',
    })
  end
end

local function setup()
  for _, marker in pairs(markers) do
    vim.cmd(marker.hl_cmd)
  end
  vim.cmd('hi def link org_hyperlink Underlined')
  load_deps()
end

return {
  apply = apply,
  setup = setup,
}

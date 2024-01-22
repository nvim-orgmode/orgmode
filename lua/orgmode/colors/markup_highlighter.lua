local config = require('orgmode.config')
local ts_utils = require('orgmode.utils.treesitter')
---@type Query
local query = nil

local valid_pre_marker_chars = { ' ', '(', '-', "'", '"', '{', '*', '/', '_', '+' }
local valid_post_marker_chars =
  { ' ', ')', '-', '}', '"', "'", ':', ';', '!', '\\', '[', ',', '.', '?', '*', '/', '_', '+' }

local markers = {
  ['*'] = {
    hl_name = 'org_bold',
    hl_cmd = 'hi def %s term=bold cterm=bold gui=bold',
    delimiter_hl = true,
    nestable = true,
    type = 'text',
  },
  ['/'] = {
    hl_name = 'org_italic',
    hl_cmd = 'hi def %s term=italic cterm=italic gui=italic',
    delimiter_hl = true,
    nestable = true,
    type = 'text',
  },
  ['_'] = {
    hl_name = 'org_underline',
    hl_cmd = 'hi def %s term=underline cterm=underline gui=underline',
    delimiter_hl = true,
    nestable = true,
    type = 'text',
  },
  ['+'] = {
    hl_name = 'org_strikethrough',
    hl_cmd = 'hi def %s term=strikethrough cterm=strikethrough gui=strikethrough',
    delimiter_hl = true,
    nestable = true,
    type = 'text',
  },
  ['~'] = {
    hl_name = 'org_code',
    hl_cmd = 'hi def link %s String',
    delimiter_hl = true,
    nestable = false,
    spell = false,
    type = 'text',
  },
  ['='] = {
    hl_name = 'org_verbatim',
    hl_cmd = 'hi def link %s String',
    delimiter_hl = true,
    nestable = false,
    spell = false,
    type = 'text',
  },
  ['\\('] = {
    hl_name = 'org_latex',
    hl_cmd = 'hi def link %s OrgTSLatex',
    nestable = false,
    spell = false,
    delimiter_hl = false,
    type = 'latex',
  },
  ['\\{'] = {
    hl_name = 'org_latex',
    hl_cmd = 'hi def link %s OrgTSLatex',
    nestable = false,
    delimiter_hl = false,
    type = 'latex',
  },
  ['\\s'] = {
    hl_name = 'org_latex',
    hl_cmd = 'hi def link %s OrgTSLatex',
    nestable = false,
    delimiter_hl = false,
    type = 'latex',
  },
}

---@param node TSNode
---@param source number
---@param offset_col_start? number
---@param offset_col_end? number
---@return string
local function get_node_text(node, source, offset_col_start, offset_col_end)
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

---@param start_node TSNode
---@param end_node TSNode
---@return boolean
local function validate(start_node, end_node)
  if not start_node or not end_node then
    return false
  end

  local start_line = start_node:range()
  local end_line = end_node:range()

  return start_line == end_line
end

---@param bufnr number
---@return TSNode|nil
local get_tree = ts_utils.memoize_by_buf_tick(function(bufnr)
  local tree = vim.treesitter.get_parser(bufnr, 'org'):parse()
  if not tree or not #tree then
    return nil
  end
  return tree[1]:root()
end)

local function get_query()
  if not query then
    query = vim.treesitter.query.get('org', 'markup') --[[@as Query]]
  end
  return query
end

local function is_valid_markup_range(match, _, source, predicates)
  local start_node = match[predicates[2]]
  local end_node = match[predicates[3]]

  local is_valid = validate(start_node, end_node)

  if not is_valid then
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

local function is_valid_hyperlink_range(match, _, source, predicates)
  local start_node = match[predicates[2]]
  local end_node = match[predicates[3]]

  local is_valid = validate(start_node, end_node)

  if not is_valid then
    return false
  end

  local start_text = get_node_text(start_node, source, 0, 1)
  local end_text = get_node_text(end_node, source, -1)

  local is_valid_start = start_text == '[['
  local is_valid_end = end_text == ']]'
  return is_valid_start and is_valid_end
end

local function is_valid_latex_range(match, _, source, predicates)
  local start_node_left = match[predicates[2]]
  local start_node_right = match[predicates[3]]
  local end_node = match[predicates[4]]
  if not start_node_right or not end_node then
    return
  end

  local start_line = start_node_left:range()
  local start_line_right = start_node_right:range()
  local end_line = end_node:range()

  if start_line ~= start_line_right or start_line ~= end_line then
    return false
  end

  local _, start_left_col_end = start_node_left:end_()
  local _, start_right_col_end = start_node_right:end_()
  local start_text = get_node_text(start_node_left, source, 0, start_right_col_end - start_left_col_end)

  if start_text == '\\(' then
    local end_text = get_node_text(end_node, source, -1, 0)
    if end_text == '\\)' then
      return true
    end
  else
    -- we have to deal with two cases here either \foo{bar} or \bar
    local char_after_start = get_node_text(start_node_right, source, 0, 1):sub(-1)
    local end_text = get_node_text(end_node, source, 0, 0)
    -- if \foo{bar}
    if char_after_start == '{' and end_text == '}' then
      return true
    end
    -- elseif \bar
    if not start_text:sub(2):match('%A') and end_text ~= '}' then
      return true
    end
  end
  return false
end

local function load_deps()
  -- Already defined
  if query then
    return
  end

  vim.treesitter.query.add_predicate('org-is-valid-markup-range?', is_valid_markup_range)
  vim.treesitter.query.add_predicate('org-is-valid-hyperlink-range?', is_valid_hyperlink_range)
  vim.treesitter.query.add_predicate('org-is-valid-latex-range?', is_valid_latex_range)
end

local function sort_entries(entries)
  return table.sort(entries, function(a, b)
    if a.range.start.line == b.range.start.line then
      return a.range.start.character < b.range.start.character
    end
    return a.range.start.line < b.range.start.line
  end)
end

local function get_links(entries)
  if not entries then
    return {}
  end

  sort_entries(entries)

  local seek = {}
  local result = {}

  for _, item in ipairs(entries) do
    if item.type == '[' then
      seek = item
    end

    if item.type == ']' and seek then
      table.insert(result, {
        from = seek.range,
        to = item.range,
      })
      seek = nil
    end
  end

  return result
end

local function generate_results(entries, self_contained_check_fn)
  local seek = {}
  local result = {}
  local nested = {}
  local can_nest = true

  sort_entries(entries)

  for _, item in ipairs(entries) do
    if markers[item.type] then
      if seek[item.type] then
        local from = seek[item.type]
        if nested[#nested] == nil or nested[#nested] == from.type then
          table.insert(result, {
            type = item.type,
            from = from.range,
            to = item.range,
          })

          seek[item.type] = nil
          nested[#nested] = nil
          can_nest = true

          for t, pos in pairs(seek) do
            if
              pos.range.start.line == from.range.start.line
              and pos.range.start.character > from.range['end'].character
              and pos.range.start.character < item.range.start.character
            then
              seek[t] = nil
            end
          end
        end
      elseif can_nest then
        if self_contained_check_fn and self_contained_check_fn(item) then
          table.insert(result, {
            type = item.type,
            from = item.range,
            to = item.range,
          })
        else
          seek[item.type] = item
          nested[#nested + 1] = item.type
          can_nest = markers[item.type].nestable
        end
      end
    end
  end

  return result
end

local function get_markup(entries)
  if not entries then
    return {}
  end

  return generate_results(entries)
end

local function get_latex(entries, bufnr)
  if not entries then
    return {}
  end

  local type_map = {
    ['('] = '\\(',
    [')'] = '\\(',
    ['}'] = '\\{',
  }

  for _, item in ipairs(entries) do
    if item.type == '(' then
      item.range.start.character = item.range.start.character - 1
    elseif item.type == 'str' then
      item.range.start.character = item.range.start.character - 1
      local char = get_node_text(item.node, bufnr, 0, 1):sub(-1)
      if char == '{' then
        item.type = '\\{'
      else
        item.type = '\\s'
      end
    end

    item.type = type_map[item.type] or item.type
  end

  return generate_results(entries, function(item)
    return item.type == '\\s'
  end)
end

---@param bufnr number
---@param line_index number
---@return table
local get_matches = ts_utils.memoize_by_buf_tick(function(bufnr, line_index, root)
  local ranges = {}
  local taken_locations = {}

  for _, match, _ in get_query():iter_matches(root, bufnr, line_index, line_index + 1) do
    for _, node in pairs(match) do
      local char = node:type()
      local marker = markers[char]
      local type = nil
      if marker then
        type = marker.type
      elseif char == '[' or char == ']' then
        type = 'link'
      elseif char ~= '\\' then
        type = 'latex'
      end

      if type then
        ranges[type] = ranges[type] or {}
        local range = ts_utils.node_to_lsp_range(node)
        local linenr = tostring(range.start.line)
        taken_locations[linenr] = taken_locations[linenr] or {}
        if not taken_locations[linenr][range.start.character] then
          table.insert(ranges[type], {
            type = char,
            range = range,
            node = node,
          })
          taken_locations[linenr][range.start.character] = true
        end
      end
    end
  end

  return {
    markup_ranges = get_markup(ranges.text),
    link_ranges = get_links(ranges.link),
    latex_ranges = get_latex(ranges.latex, bufnr),
  }
end, {
  key = function(bufnr, line_index)
    return bufnr .. '__' .. line_index
  end,
})

local function highlight_markup(namespace, bufnr, entries)
  local hide_markers = config.org_hide_emphasis_markers
  for _, entry in ipairs(entries) do
    local hl_offset = 0
    if markers[entry.type].delimiter_hl then
      hl_offset = 1
      -- Leading delimiter
      vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.start.line, entry.from.start.character, {
        ephemeral = true,
        end_col = entry.from.start.character + hl_offset,
        hl_group = markers[entry.type].hl_name .. '_delimiter',
        spell = markers[entry.type].spell,
        priority = 110 + entry.from.start.character,
      })

      -- Closing delimiter
      vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.start.line, entry.to['end'].character - hl_offset, {
        ephemeral = true,
        end_col = entry.to['end'].character,
        hl_group = markers[entry.type].hl_name .. '_delimiter',
        spell = markers[entry.type].spell,
        priority = 110 + entry.from.start.character,
      })
    end

    -- Main body highlight
    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.start.line, entry.from.start.character + hl_offset, {
      ephemeral = true,
      end_col = entry.to['end'].character - hl_offset,
      hl_group = markers[entry.type].hl_name,
      spell = markers[entry.type].spell,
      priority = 110 + entry.from.start.character,
    })

    if hide_markers then
      vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.start.line, entry.from.start.character, {
        end_col = entry.from['end'].character,
        ephemeral = true,
        conceal = '',
      })
      vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.to.start.line, entry.to.start.character, {
        end_col = entry.to['end'].character,
        ephemeral = true,
        conceal = '',
      })
    end
  end
end

local function highlight_links(namespace, bufnr, entries)
  for _, entry in ipairs(entries) do
    local line = vim.api.nvim_buf_get_lines(bufnr, entry.from.start.line, entry.from.start.line + 1, false)[1]
    local link = line:sub(entry.from.start.character + 1, entry.to['end'].character)
    local alias = link:find('%]%[') or 1
    local link_end = link:find('%]%[') or (link:len() - 1)

    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.start.line, entry.from.start.character, {
      ephemeral = true,
      end_col = entry.to['end'].character,
      hl_group = 'org_hyperlink',
      priority = 110,
    })

    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.start.line, entry.from.start.character, {
      ephemeral = true,
      end_col = entry.from.start.character + 1 + alias,
      conceal = '',
    })

    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.start.line, entry.from.start.character + 2, {
      ephemeral = true,
      end_col = entry.from.start.character - 1 + link_end,
      spell = false,
    })

    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.start.line, entry.to['end'].character - 2, {
      ephemeral = true,
      end_col = entry.to['end'].character,
      conceal = '',
    })
  end
end

local function highlight_latex(namespace, bufnr, entries)
  for _, entry in ipairs(entries) do
    vim.api.nvim_buf_set_extmark(bufnr, namespace, entry.from.start.line, entry.from.start.character, {
      ephemeral = true,
      end_col = entry.to['end'].character,
      hl_group = markers[entry.type].hl_name,
      spell = markers[entry.type].spell,
      priority = 110 + entry.from.start.character,
    })
  end
end

local function apply(namespace, bufnr, line_index)
  bufnr = bufnr or 0
  local root = get_tree(bufnr)
  if not root then
    return
  end

  local result = get_matches(bufnr, line_index, root)

  highlight_markup(namespace, bufnr, result.markup_ranges)
  highlight_links(namespace, bufnr, result.link_ranges)
  highlight_latex(namespace, bufnr, result.latex_ranges)
end

local function setup()
  for _, marker in pairs(markers) do
    vim.cmd(string.format(marker.hl_cmd, marker.hl_name))
    if marker.delimiter_hl then
      vim.cmd(string.format(marker.hl_cmd, marker.hl_name .. '_delimiter'))
    end
  end
  vim.cmd('hi def link org_hyperlink Underlined')
  load_deps()
end

return {
  apply = apply,
  setup = setup,
}

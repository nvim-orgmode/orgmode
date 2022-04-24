local config = require('orgmode.config')
local buf_blocks = {}

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

local function apply_markup_to_line(namespace, bufnr, line_index, line)
  local hl = function(from, to, opts)
    local options = vim.tbl_extend('force', { ephemeral = true, end_col = to }, opts or {})
    vim.api.nvim_buf_set_extmark(bufnr, namespace, line_index, from, options)
  end

  local hide_markers = config.org_hide_emphasis_markers
  local l = line
  local stars = l:match('^%*+%s+')
  local offset = 0
  if stars then
    l = l:sub(stars:len() + 1)
    offset = stars:len()
  end
  local chars = vim.split(l, '', true)
  local ranges = {}
  local seek = {}
  local seek_link = {}
  local link_ranges = {}

  for i, char in ipairs(chars) do
    -- Markup parsing
    if markers[char] then
      if seek[char] then
        local next_char = chars[i + 1]
        if next_char == nil or vim.tbl_contains(valid_post_marker_chars, next_char) then
          table.insert(ranges, { type = char, from = seek[char], to = i + offset })
          seek[char] = nil
        end
      else
        local prev_char = chars[i - 1]
        if prev_char == nil or vim.tbl_contains(valid_pre_marker_chars, prev_char) then
          seek[char] = i + offset
        end
      end
    end

    -- Links parsing
    if char == '[' and chars[i - 1] == '[' then
      seek_link[char] = i - 1 + offset
    end

    if char == ']' and chars[i + 1] == ']' and seek_link['['] then
      table.insert(link_ranges, { from = seek_link['['], to = i + 1 + offset })
    end
  end

  for _, range in ipairs(ranges) do
    hl(range.from - 1, range.to, {
      hl_group = markers[range.type].hl_name,
      priority = 110 + range.from,
    })
    if hide_markers then
      hl(range.from - 1, range.from, { conceal = '' })
      hl(range.to - 1, range.to, { conceal = '' })
    end
  end

  for _, link_range in ipairs(link_ranges) do
    local link = line:sub(link_range.from, link_range.to)
    local alias = link:find('%]%[') or 1
    hl(link_range.from - 1, link_range.to, {
      hl_group = 'org_hyperlink',
      priority = 200 + link_range.from,
    })
    hl(link_range.from - 1, link_range.from + alias, { conceal = '' })
    hl(link_range.to - 2, link_range.to, { conceal = '' })
  end
end

local function apply(namespace, bufnr, changed_lines, first_line, _, tick_changed)
  if not buf_blocks[bufnr] or tick_changed then
    buf_blocks = {}
    local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local seek_blocks = {}
    for i, line in ipairs(all_lines) do
      local lower_line = line:lower()
      if lower_line:match('^%s*#%+begin_') then
        if not seek_blocks.from then
          seek_blocks.from = i
        end
      end
      if lower_line:match('^%s*#%+end_') then
        if not seek_blocks.to then
          seek_blocks.to = i
        end
        if seek_blocks.from and seek_blocks.to then
          table.insert(buf_blocks, { seek_blocks.from, seek_blocks.to })
          seek_blocks = {}
        end
      end
    end
  end

  for i, line in ipairs(changed_lines) do
    local line_nr = first_line + i
    local apply_to_line = true
    for _, block in ipairs(buf_blocks) do
      if line_nr >= block[1] and line_nr <= block[2] then
        apply_to_line = false
        break
      end
    end
    if apply_to_line then
      apply_markup_to_line(namespace, bufnr, line_nr - 1, line)
    end
  end
end

local function setup()
  for _, marker in pairs(markers) do
    vim.cmd(marker.hl_cmd)
  end
  vim.cmd('hi def link org_hyperlink Underlined')
end

return {
  apply = apply,
  setup = setup,
}

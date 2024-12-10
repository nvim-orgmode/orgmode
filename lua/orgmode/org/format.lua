local org = require('orgmode')
local Table = require('orgmode.files.elements.table')

local function format_line(linenr)
  local line_text = vim.fn.getline(linenr)

  if line_text:match('^%*+%s') then
    local headline = org.files:get_closest_headline_or_nil({ linenr, 1 })
    if headline then
      headline:align_tags()
      return true
    end
  end

  local tbl = Table.from_current_node({ linenr, 0 })
  if tbl and tbl:reformat() then
    return true
  end

  local item = org.files:get_closest_headline_or_nil({ linenr, 1 })
  if item and item:get_logbook() and item:get_logbook().range:is_in_line_range(linenr) then
    item:get_logbook():recalculate_estimate(linenr)
    return true
  end

  return false
end

local formatexpr_cache = {}

local function format()
  if vim.tbl_contains({ 'i', 'R', 'ic', 'ix' }, vim.fn.mode()) then
    -- `formatexpr` is also called when exceeding `textwidth` in insert mode
    -- fall back to internal formatting
    return 1
  end

  local start_line = vim.v.lnum
  local end_line = vim.v.lnum + vim.v.count - 1
  local formatted = false

  -- If single line is being formatted and is cached in the loop below,
  -- Just fallback to internal formatting
  if start_line == end_line and formatexpr_cache[start_line] then
    return 1
  end

  for linenr = start_line, end_line do
    local line_formatted = format_line(linenr)
    if not line_formatted then
      formatexpr_cache[linenr] = true
    end
    formatted = formatted or line_formatted
  end

  for line in pairs(formatexpr_cache) do
    vim.cmd(('%dnormal! gqq'):format(line))
  end

  formatexpr_cache = {}

  return formatted and 0 or 1
end

return format

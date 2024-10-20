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

local function format()
  if vim.tbl_contains({ 'i', 'R', 'ic', 'ix' }, vim.fn.mode()) then
    -- `formatexpr` is also called when exceeding `textwidth` in insert mode
    -- fall back to internal formatting
    return 1
  end

  local start_line = vim.v.lnum
  local end_line = vim.v.lnum + vim.v.count - 1
  local formatted = false

  for linenr = start_line, end_line do
    local line_formatted = format_line(linenr)
    formatted = formatted or line_formatted
  end

  if formatted then
    return 0
  end

  return 1
end

return format

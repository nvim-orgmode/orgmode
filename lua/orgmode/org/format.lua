local Files = require('orgmode.parser.files')
local Table = require('orgmode.treesitter.table')
local ts_org = require('orgmode.treesitter')

local function format_line(linenr)
  local line_text = vim.fn.getline(linenr)

  if line_text:match('^%*+%s') then
    local headline = ts_org.closest_headline({ linenr, 1 })
    if headline then
      headline:align_tags()
      return true
    end
  end

  if Table.format(linenr) then
    return true
  end

  local ok, item = pcall(Files.get_closest_headline, linenr)
  if ok and item and item.logbook and item.logbook.range:is_in_line_range(linenr) then
    item.logbook:recalculate_estimate(linenr)
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

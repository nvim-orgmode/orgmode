local Files = require('orgmode.parser.files')
local Table = require('orgmode.treesitter.table')

local function format()
  if vim.tbl_contains({ 'i', 'R', 'ic', 'ix' }, vim.fn.mode()) then
    -- `formatexpr` is also called when exceeding `textwidth` in insert mode
    -- fall back to internal formatting
    return 1
  end

  local table = Table.format()

  if table then
    return 0
  end

  local line = vim.fn.line('.')
  local ok, item = pcall(Files.get_closest_headline, line)
  if ok and item and item.logbook and item.logbook.range:is_in_line_range(line) then
    return item.logbook:recalculate_estimate(line)
  end

  return 1
end

return format

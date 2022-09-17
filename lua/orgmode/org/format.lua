local Files = require('orgmode.parser.files')
local ts_org = require('orgmode.treesitter')
local Table = require('orgmode.treesitter.table')
local util = require('orgmode.utils')

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

  local start_line = vim.v.lnum
  local end_line = start_line + vim.v.count
  local formatted_headlines = 0

  util.echo_info('lnum: ' .. vim.v.lnum .. ', count: ' .. vim.v.count)

  for line_num = start_line, end_line, 1 do
    if vim.fn.getline(line_num):match('^%*') then
      ts_org.closest_headline():align_tags()
      formatted_headlines = formatted_headlines + 1
    end
  end

  -- it could be that there were no headlines in the selection|motion
  if formatted_headlines > 0 then
    return 0
  end

  -- return 1
end

return format

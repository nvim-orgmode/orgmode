local Files = require('orgmode.parser.files')

local function format()
  local line = vim.fn.line('.')
  local ok, item = pcall(Files.get_closest_headline, line)
  if not ok or not item then
    return 1
  end

  if item.logbook and item.logbook.range:is_in_line_range(line) then
    return item.logbook:recalculate_estimate(line)
  end

  return 1
end

return format

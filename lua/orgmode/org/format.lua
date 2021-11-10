local Files = require('orgmode.parser.files')

local function format()
  local line = vim.fn.line('.')
  local item = Files.get_closest_headline(line)
  if not item then
    return 1
  end

  if item and item.logbook and item.logbook.range:is_in_line_range(line) then
    return item.logbook:recalculate_estimate(line)
  end

  return 1
end

return format

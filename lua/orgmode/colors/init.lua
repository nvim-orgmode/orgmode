local colors = require('orgmode.colors.colors')
local M = {}

M.from_hex = function(hex_color)
   return colors.new(hex_color)
end

return M

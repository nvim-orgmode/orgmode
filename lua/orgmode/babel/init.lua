---@class OrgBabel
local Babel = {}
local Tangle = require('orgmode.babel.tangle')

---@param file OrgFile
function Babel.tangle(file)
  return Tangle:new({ file = file }):tangle()
end

return Babel

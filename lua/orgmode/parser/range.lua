local Range = {}


---@class Range
---@field start_line number
---@field start_col number
---@field end_line number
---@field end_col number

---@param data table
function Range:new(data)
  local opts = {}
  opts.start_line = data.start_line
  opts.start_col = data.start_col or 1
  opts.end_line = data.end_line
  opts.end_col = data.end_col or 1
  setmetatable(opts, self)
  self.__index = self
  return opts
end

---@param lnum number
function Range:set_end_line(lnum)
  self.end_line = lnum
end

---@param lnum number
---@return Range
function Range.from_line(lnum)
  return Range:new({ start_line = lnum, end_line = lnum })
end

return Range

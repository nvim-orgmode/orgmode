---@class Range
---@field start_line number
---@field start_col number
---@field end_line number
---@field end_col number
local Range = {}

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
---@return Range
function Range.from_line(lnum)
  return Range:new({ start_line = lnum, end_line = lnum })
end

---@param lnum string
---@return Range
function Range.for_line_hl(lnum)
  return Range:new({ start_line = lnum, end_line = lnum, end_col = 0 })
end

---@return boolean
function Range:is_same_line()
  return self.start_line == self.end_line
end

---@param line number
---@param col number
---@return boolean
function Range:is_in_range(line, col)
  return line >= self.start_line and line <= self.end_line
  and col >= self.start_col and col <= self.end_col
end

return Range

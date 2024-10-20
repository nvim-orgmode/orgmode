---@class OrgPosition
---@field start_line number start line number
---@field end_line number end line number
---@field start_col number start column number
---@field end_col number end column number
local OrgPosition = {}

---@private
function OrgPosition:_new(opts)
  local data = {}
  data.start_line = opts.start_line or 1
  data.start_col = opts.start_col or 1
  data.end_line = opts.end_line or 1
  data.end_col = opts.end_col or 1

  setmetatable(data, self)
  self.__index = self
  return data
end

---@param range OrgRange
---@private
function OrgPosition:_build_from_internal_range(range)
  return OrgPosition:_new({
    start_line = range.start_line,
    start_col = range.start_col,
    end_line = range.end_line,
    end_col = range.end_col,
  })
end

return OrgPosition

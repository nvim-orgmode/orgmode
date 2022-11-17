local Range = require('orgmode.parser.range')
local TableRow = require('orgmode.parser.table.row')

---@class Table
---@field cols_width number[]
---@field rows TableRow[]
---@field start_line number
---@field start_col number
---@field range Range
local Table = {}

function Table:new(opts)
  opts = opts or {}
  local data = {}
  data.cols_width = {}
  data.rows = {}
  data.start_line = opts.start_line or 1
  data.start_col = opts.start_col or 1
  data.range = Range:new({
    start_line = data.start_line,
    end_line = data.start_line,
    start_col = data.start_col,
  })
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param row TableRow
---@param at_position number?
---@return Table
function Table:add_row(row, at_position)
  if at_position then
    table.insert(self.rows, at_position, row)
  else
    table.insert(self.rows, row)
  end
  for col_nr, cell in ipairs(row.cells) do
    if not self.cols_width[col_nr] or self.cols_width[col_nr] < cell.display_len then
      self.cols_width[col_nr] = cell.display_len
    end
  end
  self.range.end_line = self.range.start_line + #self.rows - 1
  return self
end

function Table:populate_missing_cells()
  for _, row in ipairs(self.rows) do
    row:populate_missing_cells()
  end
  return self
end

---@return Table
function Table:compile()
  for _, row in ipairs(self.rows) do
    row:compile()
  end
  return self
end

---@return string[]
function Table:draw()
  if #self.rows > 0 and not self.rows[1]:is_compiled() then
    self:compile()
  end
  return vim.tbl_map(function(row)
    return row:to_string()
  end, self.rows)
end

---@param data table[]
---@param start_line number
---@param start_col number
---@return Table
function Table.from_list(data, start_line, start_col)
  local tbl = Table:new({
    start_line = start_line,
    start_col = start_col,
  })

  for i, row in ipairs(data or {}) do
    tbl:add_row(TableRow.from_table_item(row, i, tbl))
  end

  tbl:populate_missing_cells()

  return tbl
end

return Table

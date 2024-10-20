local Range = require('orgmode.files.elements.range')
local TableCell = require('orgmode.files.elements.table.cell')
---@class OrgTableRow
---@field table OrgTable
---@field cells OrgTableCell[]
---@field range OrgRange
---@field content string
---@field is_separator boolean
---@field line number
local TableRow = {}

function TableRow:new(opts)
  opts = opts or {}
  local data = {}
  data.table = opts.table
  data.cells = opts.cells or {}
  data.is_separator = opts.is_separator or false
  data.line = opts.line or 1
  data.range = Range.from_line(opts.table.range.start_line + data.line - 1)
  data.content = opts.content
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param cell OrgTableCell
---@return OrgTableRow
function TableRow:add_cell(cell)
  table.insert(self.cells, cell)
  return self
end

---@return OrgTableRow
function TableRow:compile()
  local row_content = {}
  for _, cell in ipairs(self.cells) do
    table.insert(row_content, cell:compile():to_string())
  end
  local separator = self.is_separator and '+' or '|'
  self.content = '|' .. table.concat(row_content, separator) .. '|'
  return self
end

---@return boolean
function TableRow:is_compiled()
  return self.content ~= nil
end

function TableRow:populate_missing_cells()
  local total_cells = #self.table.cols_width
  local cell_count = #self.cells
  if #self.table.cols_width > cell_count then
    for j = 1, total_cells - cell_count do
      self:add_cell(TableCell.from_row_item('', cell_count + j, self))
    end
  end
end

---@return string
function TableRow:to_string()
  return self.content
end

---@param row table | string
---@param line number
---@param parent_table OrgTable
---@return OrgTableRow
function TableRow.from_table_item(row, line, parent_table)
  local table_row = TableRow:new({
    table = parent_table,
    line = line,
    is_separator = type(row) == 'string' and row == 'hr',
  })
  if type(row) == 'string' then
    table_row:add_cell(TableCell.from_row_item('', 1, table_row))
  else
    for col_nr, cell_data in ipairs(row) do
      table_row:add_cell(TableCell.from_row_item(cell_data, col_nr, table_row))
    end
  end
  return table_row
end

return TableRow

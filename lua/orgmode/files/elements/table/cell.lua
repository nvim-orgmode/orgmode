local utils = require('orgmode.utils')

---@class OrgTableCell
---@field row OrgTableRow
---@field value string
---@field len number
---@field display_len number
---@field col number
---@field range OrgRange
---@field content string
---@field reference any
local TableCell = {}

function TableCell:new(opts)
  opts = opts or {}
  local data = {}
  data.row = opts.row
  data.value = opts.value
  data.len = opts.value:len()
  data.display_len = vim.api.nvim_strwidth(opts.value)
  data.col = opts.col or 1
  data.reference = opts.reference
  data.range = data.row.range:clone()
  data.content = opts.content
  setmetatable(data, self)
  self.__index = self
  return data
end

---@return OrgTableCell
function TableCell:compile()
  local width = self.row.table.cols_width[self.col]
  local val = ''
  if self.row.is_separator then
    val = string.format('-%s-', string.rep('-', width))
  else
    val = string.format(' %s ', utils.pad_right(self.value, width))
  end
  local start_col = self.row.table.start_col + 2
  if self.col > 1 then
    local prev_cell = self.row.cells[self.col - 1]
    start_col = prev_cell.range.start_col + prev_cell.content:len() + 1
  end
  self.range.start_col = start_col
  self.range.end_col = start_col + self.len - 1
  if self.value == '' then
    self.range.end_col = self.range.start_col
  end
  self.content = val
  return self
end

---@return string
function TableCell:to_string()
  return self.content
end

---@param data table | string
---@param col_number number
---@param row OrgTableRow
---@return OrgTableCell
function TableCell.from_row_item(data, col_number, row)
  local cell_data = {
    row = row,
    col = col_number,
    value = nil,
    reference = nil,
  }
  if type(data) == 'table' then
    cell_data.value = data.value
    cell_data.reference = data.reference
  else
    cell_data.value = data
  end

  return TableCell:new(cell_data)
end

return TableCell

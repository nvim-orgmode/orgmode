local Range = require('orgmode.parser.range')

---@class Table
---@field cols_width number[]
---@field rows table[]
---@field start_line number
---@field start_col number
local Table = {}

function Table:new(opts)
  opts = opts or {}
  local data = {}
  data.cols_width = opts.cols_width or {}
  data.rows = opts.rows or {}
  data.start_line = opts.start_line or 0
  data.start_col = opts.start_col or 0
  setmetatable(data, self)
  self.__index = self
  return data
end

function Table:compile()
  for row_nr, row in ipairs(self.rows) do
    local row_content = {}
    local is_separator = #row.cells == 0
    local col_counter = self.start_col + 2 -- skip the first pipe
    for i, cell in ipairs(row.cells) do
      local width = self.cols_width[i]
      local val = string.format(' %-' .. width .. 's ', cell.value)
      cell.range = Range:new({
        start_line = self.start_line + row_nr,
        end_line = self.start_line + row_nr,
        start_col = col_counter + 1,
        end_col = col_counter + cell.value:len(),
      })
      col_counter = col_counter + val:len() + 1
      table.insert(row_content, val)
    end
    if #self.cols_width > #row.cells then
      for j = 1, #self.cols_width - #row.cells do
        local width = self.cols_width[#row.cells + j]
        if is_separator then
          table.insert(row_content, string.format('-%s-', string.rep('-', width)))
        else
          table.insert(row_content, string.format(' %-' .. width .. 's ', ''))
        end
      end
    end
    local separator = is_separator and '+' or '|'
    row.content = '|' .. table.concat(row_content, separator) .. '|'
    row.is_separator = is_separator
  end
  return self
end

function Table:draw()
  if not self.rows[1].content then
    self:compile()
  end
  return vim.tbl_map(function(row)
    return row.content
  end, self.rows)
end

---@param data table[]
---@param start_line number
---@param start_col number
---@return Table
function Table.from_list(data, start_line, start_col)
  local table_data = {
    cols_width = {},
    rows = {},
    start_line = start_line,
    start_col = start_col,
  }

  for _, row in ipairs(data or {}) do
    local row_data = { cells = {} }
    for col_nr, cell in ipairs(row) do
      local cell_data = { len = 0, value = nil, reference = nil, type = 'string' }
      if type(cell) == 'table' then
        cell_data.value = cell.value
        cell_data.len = cell.value:len()
        cell_data.reference = cell.reference
      else
        cell_data.value = cell
        cell_data.len = cell:len()
      end
      -- Calculate width for each column
      if not table_data.cols_width[col_nr] or table_data.cols_width[col_nr] < cell_data.len then
        table_data.cols_width[col_nr] = cell_data.len
      end
      table.insert(row_data.cells, cell_data)
    end

    table.insert(table_data.rows, row_data)
  end

  return Table:new(table_data)
end

return Table

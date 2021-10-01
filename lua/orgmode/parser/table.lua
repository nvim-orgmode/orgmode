---@class Table
---@field cols_width number[]
---@field rows table[]
local Table = {}

function Table:new(opts)
  opts = opts or {}
  local data = {}
  data.cols_width = opts.cols_width or {}
  data.rows = opts.rows or {}
  setmetatable(data, self)
  self.__index = self
  return data
end

function Table:draw()
  local content = {}
  for _, row in ipairs(self.rows) do
    local row_content = {}
    local is_separator = #row == 0
    for i, cell in ipairs(row) do
      local width = self.cols_width[i]
      table.insert(row_content, string.format(' %-' .. width .. 's ', cell.value))
    end
    if #self.cols_width > #row then
      for j = 1, #self.cols_width - #row do
        local width = self.cols_width[#row + j]
        if is_separator then
          table.insert(row_content, string.format('-%s-', string.rep('-', width)))
        else
          table.insert(row_content, string.format(' %-' .. width .. 's ', ''))
        end
      end
    end
    local separator = is_separator and '+' or '|'
    table.insert(content, '|' .. table.concat(row_content, separator) .. '|')
  end
  return content
end

---@param data table[]
---@return Table
function Table.from_list(data)
  local table_data = {
    cols_width = {},
    rows = {},
  }

  for _, row in ipairs(data or {}) do
    local row_data = {}
    for col_nr, cell in ipairs(row) do
      local cell_len = cell:len()
      -- Calculate width for each column
      if not table_data.cols_width[col_nr] or table_data.cols_width[col_nr] < cell_len then
        table_data.cols_width[col_nr] = cell_len
      end
      local cell_data = {
        len = cell_len,
        value = cell,
        type = 'string',
      }
      table.insert(row_data, cell_data)
    end

    table.insert(table_data.rows, row_data)
  end

  return Table:new(table_data)
end

return Table

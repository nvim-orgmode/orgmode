local Range = require('orgmode.files.elements.range')
local TableRow = require('orgmode.files.elements.table.row')
local ts_utils = require('orgmode.utils.treesitter')
local utils = require('orgmode.utils')
local config = require('orgmode.config')

---@class OrgTable
---@field cols_width number[]
---@field rows OrgTableRow[]
---@field start_line number
---@field start_col number
---@field node? TSNode
---@field file? OrgFile
---@field range OrgRange
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

---@param cursor? table
---@return OrgTable | nil
function Table.from_current_node(cursor)
  ts_utils.parse_current_file()
  -- Get node from last column so we are sure we can find the table.
  -- If column is less than indentation of table, we will miss it.
  if not cursor then
    cursor = vim.api.nvim_win_get_cursor(0)
    cursor[2] = vim.fn.col('$')
  end
  local node = ts_utils.get_node_at_cursor(cursor)
  if not node then
    return nil
  end
  if node:type() ~= 'table' then
    node = ts_utils.closest_node(node, 'table')
  end

  if not node then
    return nil
  end

  local rows = {}

  for row in node:iter_children() do
    if row:type() == 'hr' then
      table.insert(rows, 'hr')
    end
    if row:type() == 'row' then
      local row_data = {}
      for cell in row:iter_children() do
        if cell:type() == 'cell' then
          local cell_val = ''
          local cell_content = cell:field('contents')
          if cell_content and #cell_content > 0 then
            cell_val = vim.treesitter.get_node_text(cell_content[1], 0)
          end
          table.insert(row_data, cell_val)
        end
      end
      table.insert(rows, row_data)
    end
  end

  local start_row, start_col = node:range()
  local tbl = Table.from_list(rows, start_row + 1, start_col + 1)
  tbl.node = node
  return tbl
end

function Table:reformat()
  if not self.node then
    return false
  end
  local _, start_col = self.node:range()
  local indent = config:get_indent(start_col, vim.api.nvim_get_current_buf())
  local contents = vim.tbl_map(function(line)
    return ('%s%s'):format(indent, line)
  end, self:draw())

  local view = vim.fn.winsaveview() or {}
  vim.api.nvim_buf_set_lines(0, self.range.start_line - 1, self.range.end_line, false, contents)
  vim.fn.winrestview(view)
  return true
end

function Table:handle_cr()
  if vim.fn.col('.') == vim.fn.col('$') then
    return false
  end

  local line = vim.fn.line('.') or 0
  local indent_amount = vim.fn.indent(line) or 0
  local indent = config:get_indent(indent_amount, vim.api.nvim_get_current_buf())
  vim.api.nvim_buf_set_lines(0, line, line, true, { ('%s|'):format(indent) })
  local tbl = Table.from_current_node({ line, vim.fn.col('.') })
  if tbl then
    tbl:reformat()
  end
  vim.api.nvim_feedkeys(utils.esc('<Down>'), 'n', true)
  vim.schedule(function()
    vim.cmd([[norm! F|]])
    vim.api.nvim_feedkeys(utils.esc('<Right><Right>'), 'n', true)
  end)
  return true
end

---@param row OrgTableRow
---@param at_position number?
---@return OrgTable
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

---@return OrgTable
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
---@return OrgTable
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

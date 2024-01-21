local ts_utils = require('orgmode.utils.treesitter')
local Table = require('orgmode.parser.table')
local utils = require('orgmode.utils')
local config = require('orgmode.config')

---@class TsTable
---@field node TSNode
---@field data table[]
---@field tbl Table
local TsTable = {}

function TsTable.from_current_node(linenr)
  vim.treesitter.get_parser(0, 'org', {}):parse()
  local cursor = vim.api.nvim_win_get_cursor(0)
  if linenr then
    local line = vim.fn.getline(linenr)
    local spaces = line:match('^%s*')
    local col = spaces and spaces:len() or 0
    cursor = { linenr, col }
  end
  local node = ts_utils.get_node_at_cursor(cursor)
  if not node then
    return false
  end
  local table_node = utils.get_closest_parent_of_type(node, 'table', true)
  if not table_node then
    return false
  end
  return TsTable:new({ node = table_node })
end

function TsTable:new(opts)
  local data = {}
  data.node = opts.node
  setmetatable(data, self)
  self.__index = self
  data:_parse_data()
  return data
end

---@private
--- Parse table data from node
function TsTable:_parse_data()
  local rows = {}
  for row in self.node:iter_children() do
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

  self.data = rows
  local start_row, start_col = self.node:range()
  self.tbl = Table.from_list(self.data, start_row + 1, start_col + 1)
end

function TsTable:reformat()
  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(0, self.tbl.range.start_line - 1, self.tbl.range.end_line, false, self:_get_content())
  vim.fn.winrestview(view)
end

---@private
function TsTable:_get_content()
  local start_row = self.node:range()
  local first_line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, true)
  local indent = first_line and first_line[1]:match('^%s*') or ''
  indent = config:get_indent(indent:len())

  local contents = self.tbl:draw()
  local indented = {}
  for _, content in ipairs(contents) do
    table.insert(indented, string.format('%s%s', indent, content))
  end

  return indented
end

function TsTable:add_row()
  local line = vim.fn.line('.')
  local indent = config:get_indent(vim.fn.indent(line))
  vim.api.nvim_buf_set_lines(0, line, line, true, { ('%s|'):format(indent) })
  return TsTable.from_current_node():reformat()
end

local function format(linenr)
  local tbl = TsTable.from_current_node(linenr)

  if not tbl then
    return false
  end

  tbl:reformat()
  return true
end

local function handle_cr()
  if vim.fn.col('.') == vim.fn.col('$') then
    return false
  end
  local tbl = TsTable.from_current_node()
  if not tbl then
    return false
  end

  tbl:add_row()
  vim.api.nvim_feedkeys(utils.esc('<Down>'), 'n', true)
  vim.schedule(function()
    vim.cmd([[norm! F|]])
    vim.api.nvim_feedkeys(utils.esc('<Right><Right>'), 'n', true)
  end)
  return true
end

return {
  format = format,
  handle_cr = handle_cr,
}

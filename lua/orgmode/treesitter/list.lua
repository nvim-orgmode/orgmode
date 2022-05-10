local ts_utils = require('nvim-treesitter.ts_utils')
local tree_utils = require('orgmode.utils.treesitter')
local query = vim.treesitter.query

local List = {}

function List:new(list_node)
  local data = { list = list_node }
  setmetatable(data, self)
  self.__index = self
  return data
end

function List:checkboxes()
  return vim.tbl_map(function(node)
    local text = query.get_node_text(node, 0)
    return text:match('%[.%]')
  end, ts_utils.get_named_children(self.list))
end

return List

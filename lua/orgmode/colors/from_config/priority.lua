local config = require('orgmode.config')

local M = {}

function M.get_queries()
  return vim.tbl_map(function(priority)
    return string.format('((expr) @OrgPriority%s (#eq? @OrgPriority%s "[#%s]"))', priority, priority, priority)
  end, config:get_priority_values())
end

---@type OrgConfigHighlighter
return M

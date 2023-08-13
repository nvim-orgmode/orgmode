local ts = require('orgmode.treesitter.compat')
local tree_utils = require('orgmode.utils.treesitter')
local utils = require('orgmode.utils')

local M = {}

---@class OrgConfigHighlighter
---@field get_queries function()

function M.setup()
  local query_files = ts.get_query_files('org', 'highlights')
  if not query_files or #query_files == 0 then
    return
  end

  local all_lines = {}
  for i, _ in pairs(query_files) do
    if i ~= #query_files then
      utils.readfile(
        query_files[i],
        vim.schedule_wrap(function(err, lines)
          if err then
            return
          end
          for _, v in ipairs(lines) do
            table.insert(all_lines, v)
          end
        end)
      )
    else
      utils.readfile(
        query_files[i],
        vim.schedule_wrap(function(err, lines)
          if err then
            return
          end
          for _, v in
            ipairs(vim.tbl_flatten({
              require('orgmode.colors.from_config.todo').get_queries(),
              require('orgmode.colors.from_config.priority').get_queries(),
            }))
          do
            table.insert(all_lines, v)
          end
          for _, v in ipairs(lines) do
            table.insert(all_lines, v)
          end
          ts.set_query('org', 'highlights', table.concat(all_lines, '\n'))
          if vim.bo.filetype == 'org' then
            tree_utils.restart_highlights()
          end
        end)
      )
    end
  end
end

return M

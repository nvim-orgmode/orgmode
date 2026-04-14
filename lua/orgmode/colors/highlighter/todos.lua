local highlights = require('orgmode.colors.highlights')
local utils = require('orgmode.utils')
local Async = require('orgmode.utils.async')
local tree_utils = require('orgmode.utils.treesitter')

---@class OrgTodosHighlighter
local OrgTodos = {}

function OrgTodos:new()
  local data = {}
  setmetatable(data, self)
  self.__index = self
  data:_add_highlights()
  return data
end

function OrgTodos:_add_highlights()
  local query_files = vim.treesitter.query.get_files('org', 'highlights')
  if not query_files or #query_files == 0 then
    return
  end
  local faces = highlights.define_todo_keyword_faces()
  if not faces or vim.tbl_isempty(faces) then
    return
  end

  return Async.run(function()
    local line_parts = Async.map(function(query_file, index)
      local lines = utils.readfile(query_file):await()
      if index == #query_files then
        for face_name, face_hl in pairs(faces) do
          table.insert(lines, string.format([[(item . (expr) %s @nospell (#eq? %s %s))]], face_hl, face_hl, face_name))
        end
      end
      return lines
    end, query_files):await()
    local all_lines = {}
    for _, line_part in ipairs(line_parts) do
      utils.concat(all_lines, line_part)
    end
    vim.treesitter.query.set('org', 'highlights', table.concat(all_lines, '\n'))
    if vim.bo.filetype == 'org' then
      tree_utils.restart_highlights()
    end
  end)
end

return OrgTodos

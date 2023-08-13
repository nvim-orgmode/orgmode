local config = require('orgmode.config')
local highlights = require('orgmode.colors.highlights')

local M = {}

function M.get_queries()
  local todo_keywords = config:get_todo_keywords()
  local faces = highlights.parse_todo_keyword_faces()
  local todo_type = table.concat(
    vim.tbl_map(function(word)
      return string.format('"%s"', word)
    end, todo_keywords.TODO),
    ' '
  )
  local done_type = table.concat(
    vim.tbl_map(function(word)
      return string.format('"%s"', word)
    end, todo_keywords.DONE),
    ' '
  )

  local queries = {
    string.format([[(item . (expr) @OrgTODO @nospell (#any-of? @OrgTODO %s))]], todo_type),
    string.format([[(item . (expr) @OrgDONE @nospell (#any-of? @OrgDONE %s))]], done_type),
  }

  for face_name, face_hl in pairs(faces) do
    table.insert(queries, string.format([[(item . (expr) @%s @nospell (#eq? @%s %s))]], face_hl, face_hl, face_name))
  end

  return queries
end

---@type OrgConfigHighlighter
return M

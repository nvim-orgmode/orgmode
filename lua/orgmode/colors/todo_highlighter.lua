local config = require('orgmode.config')
local highlights = require('orgmode.colors.highlights')
local utils = require('orgmode.utils')

local function add_todo_keyword_highlights()
  local ts_highlights_enabled = config:ts_highlights_enabled()
  if not ts_highlights_enabled then
    return
  end
  local query_files = vim.treesitter.get_query_files('org', 'highlights')
  if not query_files or #query_files == 0 then
    return
  end
  local todo_keywords = config:get_todo_keywords()
  local faces = highlights.parse_todo_keyword_faces()
  utils.readfile(
    query_files[1],
    vim.schedule_wrap(function(err, lines)
      if err then
        return
      end
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
      table.insert(lines, string.format([[(item . (expr) @OrgTODO (#any-of? @OrgTODO %s))]], todo_type))
      table.insert(lines, string.format([[(item . (expr) @OrgDONE (#any-of? @OrgDONE %s))]], done_type))
      for face_name, face_hl in pairs(faces) do
        table.insert(lines, string.format([[(item . (expr) @%s (#eq? @%s %s))]], face_hl, face_hl, face_name))
      end
      vim.treesitter.set_query('org', 'highlights', table.concat(lines, '\n'))
      if vim.bo.filetype == 'org' then
        vim.cmd([[filetype detect]])
      end
    end)
  )
end

return {
  add_todo_keyword_highlights = add_todo_keyword_highlights,
}

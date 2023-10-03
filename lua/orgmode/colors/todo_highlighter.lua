local config = require('orgmode.config')
local highlights = require('orgmode.colors.highlights')
local tree_utils = require('orgmode.utils.treesitter')
local utils = require('orgmode.utils')

local function add_todo_keyword_highlights()
  local query_files = vim.treesitter.query.get_files('org', 'highlights')
  if not query_files or #query_files == 0 then
    return
  end
  local faces = highlights.parse_todo_keyword_faces()
  if not faces or vim.tbl_isempty(faces) then
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
          for face_name, face_hl in pairs(faces) do
            table.insert(
              lines,
              string.format([[(item . (expr) @%s @nospell (#eq? @%s %s))]], face_hl, face_hl, face_name)
            )
          end
          for _, v in ipairs(lines) do
            table.insert(all_lines, v)
          end
          vim.treesitter.query.set('org', 'highlights', table.concat(all_lines, '\n'))
          if vim.bo.filetype == 'org' then
            tree_utils.restart_highlights()
          end
        end)
      )
    end
  end
end

return {
  add_todo_keyword_highlights = add_todo_keyword_highlights,
}

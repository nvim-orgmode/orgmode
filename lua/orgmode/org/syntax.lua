local config = require('orgmode.config')

local function add_todo_keywords_to_spellgood()
  local todo_keywords = config:get_todo_keywords().ALL
  for _, todo_keyword in ipairs(todo_keywords) do
    vim.cmd(string.format('silent! spellgood! %s', todo_keyword))
  end
end

return {
  add_todo_keywords_to_spellgood = add_todo_keywords_to_spellgood,
}

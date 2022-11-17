local Files = require('orgmode.parser.files')
local config = require('orgmode.config')
local utils = require('orgmode.utils')

local function load_code_blocks()
  local file = utils.current_file_path()
  if not file or file == '' then
    return
  end

  local orgfile = Files.get(file)
  if not orgfile then
    return
  end

  local loaded_filetypes = {}

  for _, ft in ipairs(orgfile.source_code_filetypes) do
    local ok, result = pcall(vim.api.nvim_get_runtime_file, string.format('syntax/%s.vim', ft), false)
    if ok and #result > 0 then
      vim.cmd(string.format([[silent! syntax include @orgmodeBlockSrc%s syntax/%s.vim]], ft, ft))
      vim.cmd([[unlet! b:current_syntax]])
      table.insert(loaded_filetypes, ft)
    end
  end

  for _, ft in ipairs(loaded_filetypes) do
    vim.cmd(
      string.format(
        [[syntax region orgmodeBlockSrc%s matchgroup=comment start="^\s*#+\(BEGIN_SRC\|begin_src\)\ %s\s*.*$" end="^\s*#+\(END_SRC\|end_src\)\s*$" keepend contains=@orgmodeBlockSrc%s,org_block_delimiter]],
        ft,
        ft,
        ft
      )
    )
  end
end

local function add_todo_keywords_to_spellgood()
  local todo_keywords = config:get_todo_keywords().ALL
  for _, todo_keyword in ipairs(todo_keywords) do
    vim.cmd(string.format('silent! spellgood! %s', todo_keyword))
  end
end

return {
  load_code_blocks = load_code_blocks,
  add_todo_keywords_to_spellgood = add_todo_keywords_to_spellgood,
}

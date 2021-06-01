local Files = require('orgmode.parser.files')

-- Check issues with multiple sourcing and why javascript is not properly sourced
local function load_code_block_syntax(file)
  local orgfile = Files.get(file)
  if not orgfile then return end
  for _, ft in ipairs(orgfile.source_code_filetypes) do
    vim.cmd(string.format([[syntax include @orgmodeBlockSrc%s syntax/%s.vim]], ft, ft))
    vim.cmd(string.format([[syntax region orgmodeBlockSrc%s matchgroup=comment start="#+BEGIN_SRC\ %s" end="#+END_SRC" keepend contains=@orgmodeBlockSrc%s]], ft, ft, ft))
  end
end

return {
  load_code_block_syntax = load_code_block_syntax,
}

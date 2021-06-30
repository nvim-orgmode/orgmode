local Files = require('orgmode.parser.files')

local function load_code_blocks()
  local file = vim.api.nvim_buf_get_name(0)
  if not file or file == '' then return end

  local orgfile = Files.get(file)
  if not orgfile then return end

  for _, ft in ipairs(orgfile.source_code_filetypes) do
    vim.cmd(string.format([[syntax include @orgmodeBlockSrc%s syntax/%s.vim]], ft, ft))
    vim.cmd[[unlet! b:current_syntax]]
  end

  for _, ft in ipairs(orgfile.source_code_filetypes) do
    vim.cmd(string.format([[syntax region orgmodeBlockSrc%s matchgroup=comment start="^\s*#+BEGIN_SRC\ %s\s*$" end="^\s*#+END_SRC\s*$" keepend contains=@orgmodeBlockSrc%s,org_block_delimiter]], ft, ft, ft))
  end
end

return {
  load_code_blocks = load_code_blocks,
}

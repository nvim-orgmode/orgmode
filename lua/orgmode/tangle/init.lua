local ts_org = require('orgmode.treesitter')
local ts = require('orgmode.treesitter.compat')
local utils = require('orgmode.utils')

-- Expand a relative path given an origin file (took from the one found in Hyperlinks module)
---@param relative_path string The relative path to expand
---@param origin string The file which path is the relative to our
---@private
local function _expand_relative_path(relative_path, origin)
  local path = relative_path
  if path:match('^/') then
    return path
  end
  path = path:gsub('^./', '')
  return vim.fn.fnamemodify(origin, ':p:h') .. '/' .. path
end

-- Fix indentation in code blocks (remove unnecessary whitespaces)
---@param str string The string that need to be fixed (usually, a code block content)
---@param to_trim number The number of whitespaces (spaces or tabs) to remove at the start of the line
---@private
local fix_indentation = function(str, to_trim)
  if to_trim == nil then
    -- Arbitrarily large number
    to_trim = 1000
  end

  -- Understand the minimum numbers of whitespaces in the code in order to remove ORG indentation from the code
  for spaces in string.gmatch(str, '\n([ \t]+)') do
    if to_trim > #spaces then
      to_trim = #spaces
    end
  end

  local pattern = '\n'
  pattern = pattern .. string.rep('[ \t]', to_trim)

  local indented = string.gsub(str, pattern, '\n')
  return indented
end

-- Save the loaded blocks into a file
---@param files table<string, table<string>> A table that correlates file names to a list of code blocks
---@private
local save_into_files = function(files)
  if next(files) == nil then
    print('Nothing to tangle.')
    return
  end

  local out = 'Tangled files: '
  for filename, code_blocks in pairs(files) do
    -- Without expanding the file will be nil
    local file = io.open(vim.fn.expand(filename), 'w+')
    if not file then
      utils.echo_error(string.format('Cannot open file "%s"', file))
    else
      io.output(file)
      for _, block in ipairs(code_blocks) do
        io.write(block .. '\n\n')
      end
      io.close(file)
      out = out .. filename .. ' '
    end
  end
  utils.echo_info(out)
end

local BLOCK_QUERY = ts.parse_query(
  'org',
  [[
    (block
      name: (expr) @name (#eq? @name "src")
      parameter: (expr) @language
      (contents) @content) @block
  ]]
)

local function get_code_blocks(root)
  local blocks = {}
  local visited = {}
  for _, match, _ in BLOCK_QUERY:iter_matches(root, 0, 0, -1) do
    local capture_range = match[#match]:range(false)

    if not visited[capture_range] then
      local block_info = {}
      for id, node in pairs(match) do
        local name = BLOCK_QUERY.captures[id]
        block_info[name] = {
          node = node,
          text = ts.get_node_text(node, 0),
        }
      end
      table.insert(blocks, block_info)
    end

    visited[capture_range] = true
  end

  return blocks
end

-- Main function that recursively check for code blocks to be tangled
---@param root any The current node to inspect
---@param files table<string, table<string>> The map between filenames and codeblocks to tangle
local function process_code_blocks(root, files, file)
  if root == nil then
    return
  end

  local blocks = get_code_blocks(root)

  for _, block in ipairs(blocks) do
    local block_node = block.block.node
    local properties = ts_org.get_node_properties(block_node)
    local cur_file = properties.tangle

    if cur_file then
      cur_file = _expand_relative_path(cur_file, file.filename)

      if not files[cur_file] then
        files[cur_file] = {}
      end

      local content_node = block.content.node
      local _, col = content_node:range()
      table.insert(files[cur_file], fix_indentation(block.content.text, col))
    end
  end
end

---@param file File the file to be tangled
local tangle_file = function(file)
  local files_to_blocks = {}

  process_code_blocks(file.tree:root(), files_to_blocks, file)
  save_into_files(files_to_blocks)
end

return {
  tangle_file = tangle_file,
}

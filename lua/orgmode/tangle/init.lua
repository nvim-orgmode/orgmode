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

-- Setup abbreviation
local query = vim.treesitter.query

-- Fix indentation in code blocks (remove unnecessary whitespaces)
---@param str string The string that need to be fixed (usually, a code block content)
---@param to_trim number The number of whitespaces (spaces or tabs) to remove at the start of the line
---@private
local fix_indentation = function (str, to_trim)
    if to_trim == nil then
        -- Arbitrarily large number
        to_trim = 1000
    end

    -- Understand the minimum numbers of whitespaces in the code in order to remove ORG indentation from the code
    for spaces in string.gmatch(str, "\n([ \t]+)") do
        if to_trim > #spaces then
            to_trim = #spaces
        end
    end

    local pattern = "\n"
    pattern = pattern .. string.rep("[ \t]", to_trim)

    local indented = string.gsub(str, pattern, "\n")
    return indented
end

-- Save the loaded blocks into a file
---@param files table<string, table<string>> A table that correlates file names to a list of code blocks
---@private
local save_into_files = function (files)

    if next(files) == nil then
        print("Nothing to tangle.")
        return
    end

    local out = "Tangled files: "
    for filename, code_blocks in pairs(files) do
        -- Without expanding the file will be nil
        local file = io.open(vim.fn.expand(filename), "w+")
        io.output(file)
        for _, block in ipairs(code_blocks) do
            io.write(block .. "\n\n")
        end
        io.close(file)
        out = out .. filename .. " "
    end
    print(out)
end

-- necessary for recursion in this case
local process_node = nil
-- Main function that recursively check for code blocks to be tangled
---@param node any The current node to inspect
---@param cur_file string The name of the file as stated in the :TANGLE: property in the enclosing headline
---@param files table<string, table<string>> The map between filenames and codeblocks to tangle
process_node = function (node, cur_file, files, file)
    if node == nil then
        return
    end

    for subnode in node:iter_children() do
        local t = subnode:type()
        -- If the node is a block, add it to the blocks that need to be tangled if necessary
        if t == "block" then
            if cur_file ~= nil then
                if files[cur_file] == nil then
                    files[cur_file] = {}
                end

                for block_prop in subnode:iter_children() do
                    if block_prop:type() == "contents" then
                        local _, col = block_prop:range()
                        table.insert(files[cur_file], fix_indentation(query.get_node_text(block_prop, 0), col))
                    end
                end
            end
        -- It was necessary to start from property_drawer, in order to
        -- pass "cur_file" to the node inside the section body
        elseif t == "property_drawer" then
            for drawer_child in subnode:iter_children() do
                if drawer_child:type() == "property" then
                    local is_tangle = false
                    -- Look for the property name and value
                    for prop_part in drawer_child:iter_children() do
                        local prop_type = prop_part:type()
                        local prop_text = query.get_node_text(prop_part, 0)
                        if prop_type == "expr" and prop_text == "TANGLE" then
                            is_tangle = true
                        elseif prop_type == "value" and is_tangle then
                            cur_file = _expand_relative_path(prop_text, file.filename)
                            is_tangle = false
                        end
                    end

                    if is_tangle == true then
                        -- TODO: What to do if the filename is not defined?
                        is_tangle = false
                    end
                end
            end
        else
            process_node(subnode, cur_file, files, file)
        end
    end
end

---@param file File the file to be tangled
local tangle_file = function (file)
    local files_to_blocks = {}

    local root = file.tree:root()

    process_node(root, nil, files_to_blocks, file)
    save_into_files(files_to_blocks)
end

return {
    tangle_file = tangle_file
}

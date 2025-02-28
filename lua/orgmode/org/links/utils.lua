local utils = require('orgmode.utils')
local link_utils = {}

local external_filetypes = {
  -- pdf is considered a valid filetype even though it cannot be correctly read
  'pdf',
}

---@param filename string
---@return boolean - if editable, returns true, otherwise false
local function edit_file(filename)
  local filetype = vim.filetype.match({ filename = filename })
  if not filetype or vim.tbl_contains(external_filetypes, filetype) then
    vim.ui.open(filename)
    return false
  end
  vim.cmd(('edit %s'):format(filename))
  return true
end

---@param file OrgFile
---@return boolean
function link_utils.goto_file(file)
  edit_file(file.filename)
  return true
end

---@param headlines OrgHeadline[]
---@param file_path string
---@param error_message string
---@return boolean
function link_utils.goto_oneof_headlines(headlines, file_path, error_message)
  if #headlines == 0 then
    if file_path ~= utils.current_file_path() then
      vim.cmd(('edit %s'):format(file_path))
    end
    utils.echo_warning(error_message)
    return true
  end

  if #headlines == 1 then
    utils.goto_headline(headlines[1])
    return true
  end

  local longest_headline = utils.reduce(headlines, function(acc, h)
    return math.max(acc, h:get_headline_line_content():len())
  end, 0)
  local options = {}
  for i, h in ipairs(headlines) do
    table.insert(
      options,
      string.format('%d) %-' .. longest_headline .. 's (%s)', i, h:get_headline_line_content(), h.file.filename)
    )
  end
  vim.cmd([[echo "Multiple targets found. Select target:"]])
  local choice = vim.fn.inputlist(options)
  if choice < 1 or choice > #headlines then
    return true
  end

  utils.goto_headline(headlines[choice])
  return true
end

---@param file_path string
---@param search_text string | nil
---@return boolean
function link_utils.open_file_and_search(file_path, search_text)
  if not file_path or file_path == '' then
    return true
  end
  if file_path ~= utils.current_file_path() then
    local editable = edit_file(file_path)
    -- Return without attempt to find text. File is not editable.
    if not editable then
      return true
    end
  end

  if not search_text or search_text == '' then
    return true
  end

  local result = vim.fn.search(search_text, 'W')
  if result == 0 then
    utils.echo_warning(string.format('No match found for expression: %s', search_text))
  end
  return true
end

return link_utils

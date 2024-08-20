local utils = require('orgmode.utils')
local link_utils = {}

---@param file OrgFile
---@return boolean
function link_utils.goto_file(file)
  vim.cmd(('edit %s'):format(file.filename))
  return true
end

---@param headline OrgHeadline
---@return boolean
function link_utils.goto_headline(headline)
  local current_file_path = utils.current_file_path()
  if headline.file.filename ~= current_file_path then
    vim.cmd(string.format('edit %s', headline.file.filename))
  else
    vim.cmd([[normal! m']]) -- add link source to jumplist
  end
  vim.fn.cursor({ headline:get_range().start_line, 1 })
  vim.cmd([[normal! zv]])
  return true
end

---@param headlines OrgHeadline[]
---@return boolean
function link_utils.goto_oneof_headlines(headlines)
  if #headlines == 0 then
    return false
  end

  if #headlines == 1 then
    return link_utils.goto_headline(headlines[1])
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
    return false
  end

  return link_utils.goto_headline(headlines[choice])
end

return link_utils

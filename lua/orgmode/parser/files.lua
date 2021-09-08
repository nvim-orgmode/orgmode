local config = require('orgmode.config')
local File = require('orgmode.parser.file')

---@class Files
local Files = {
  loaded = false,
  orgfiles = {},
  tags = {},
}

function Files.new()
  Files.load()
  return Files
end

function Files.load(callback)
  local files = config:get_all_files()
  Files.orgfiles = {}
  if #files == 0 then
    Files.loaded = true
    if callback then
      callback()
    end
    return Files
  end
  local files_to_process = #files
  for _, item in ipairs(files) do
    File.load(item, function(file)
      files_to_process = files_to_process - 1
      if file then
        Files.orgfiles[item] = file
      end

      if files_to_process == 0 then
        Files._build_tags()
        Files.loaded = true
        if callback then
          callback()
        end
      end
    end)
  end

  return Files
end

function Files.reload(file, callback)
  if file then
    local prev_file = Files.get(file)
    return File.load(file, function(orgfile)
      if orgfile then
        Files.orgfiles[file] = orgfile
        Files._check_source_blocks(prev_file, Files.get(file))
      end
      Files.loaded = true
      if callback then
        callback()
      end
      Files._build_tags()
      return Files.get(file)
    end)
  end

  return Files.load(callback)
end

---@return File[]
function Files.all()
  Files.ensure_loaded()
  local files = vim.tbl_values(Files.orgfiles)
  table.sort(files, function(a, b)
    return a.category < b.category
  end)
  return files
end

---@return string[]
function Files.filenames()
  return vim.tbl_map(function(file)
    return file.filename
  end, Files.all())
end

---@param file string
---@return File
function Files.get(file)
  return Files.orgfiles[file]
end

---@return string[]
function Files.get_tags()
  return Files.tags
end

---@return File
function Files.get_current_file()
  local name = vim.api.nvim_buf_get_name(0)
  local has_capture_var, is_capture = pcall(vim.api.nvim_buf_get_var, 0, 'org_capture')
  if has_capture_var and is_capture then
    return File.from_content(vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end
  local file = Files.get(name)
  if file then
    Files.orgfiles[name] = file:refresh()
    return Files.get(name)
  end
  return nil
end

---@return Section
function Files.get_current_item()
  local file = Files.get_current_file()
  return file:get_current_item()
end

---@param title string
---@return Section[]
function Files.find_headlines_by_title(title)
  local headlines = {}
  for _, orgfile in ipairs(Files.all()) do
    for _, headline in ipairs(orgfile:find_headlines_by_title(title)) do
      table.insert(headlines, headline)
    end
  end
  return headlines
end

---@param property_name string
---@param term string
---@return Section[]
function Files.find_headlines_with_property_matching(property_name, term)
  local headlines = {}
  for _, orgfile in ipairs(Files.all()) do
    for _, headline in ipairs(orgfile:find_headlines_with_property_matching(property_name, term)) do
      table.insert(headlines, headline)
    end
  end
  return headlines
end

---@param filename string
---@param action function
---@return boolean
function Files.update_file(filename, action)
  local file = Files.get(filename)
  if not file then
    return false
  end
  local is_same_file = filename == vim.api.nvim_buf_get_name(0)
  local cur_win = vim.api.nvim_get_current_win()
  if is_same_file then
    if action then
      action(file)
    end
    vim.cmd(':silent! w')
    return true
  end
  local old_height = vim.api.nvim_win_get_height(0)
  vim.cmd('silent! topleft split ' .. filename)
  if action then
    action(file)
  end
  vim.cmd('silent! wq!')
  vim.api.nvim_set_current_win(cur_win)
  vim.cmd(string.format('silent! resize %d', old_height))
  return true
end

---@param term string
---@param no_escape boolean
---@return Section
function Files.find_headlines_matching_search_term(term, no_escape)
  local headlines = {}
  for _, orgfile in ipairs(Files.all()) do
    for _, headline in ipairs(orgfile:find_headlines_matching_search_term(term, no_escape)) do
      table.insert(headlines, headline)
    end
  end
  return headlines
end

---@return Section
function Files.get_closest_headline()
  return Files.get_current_file():get_closest_headline()
end

function Files._build_tags()
  local tags = {}
  for _, orgfile in pairs(Files.orgfiles) do
    for _, headline in ipairs(orgfile:get_headlines()) do
      if headline.tags and #headline.tags > 0 then
        for _, tag in ipairs(headline.tags) do
          tags[tag] = 1
        end
      end
    end
  end
  local taglist = vim.tbl_keys(tags)
  table.sort(taglist)
  Files.tags = taglist
end

function Files.autocomplete_tags(arg_lead)
  local join_char = '[%+%-:&|]'
  local parts = vim.split(arg_lead, join_char)
  local base = arg_lead:gsub('[^%+%-:&|]*$', '')
  local last = arg_lead:match('[^%+%-:&|]*$')
  local matches = vim.tbl_filter(function(tag)
    return tag:match('^' .. vim.pesc(last)) and not vim.tbl_contains(parts, tag)
  end, Files.get_tags())

  return vim.tbl_map(function(tag)
    return base .. tag
  end, matches)
end

---@param old_file? File
---@param new_file File
function Files._check_source_blocks(old_file, new_file)
  local old_source_blocks = old_file and old_file.source_code_filetypes or {}
  local new_source_blocks = new_file.source_code_filetypes or {}
  for _, ft in ipairs(new_source_blocks) do
    if not vim.tbl_contains(old_source_blocks, ft) then
      return vim.schedule(function()
        vim.cmd([[filetype detect]])
      end)
    end
  end
end

function Files.ensure_loaded()
  if Files.loaded then
    return true
  end
  vim.wait(5000, function()
    return Files.loaded
  end, 5)
end

return Files

local utils = require('orgmode.utils')
local parser = require('orgmode.parser')
local config = require('orgmode.config')

---@class OrgFiles
---@field files Root[]
---@field tags string[]
local Files = {
  files = {},
  tags = {}
}

function Files.new()
  Files.load()
  return Files
end

---@return Root[]
function Files.all()
  local files = vim.tbl_values(Files.files)
  files = vim.tbl_filter(function(file)
    return not file.is_archive_file
  end, files)
  table.sort(files, function(a, b) return a.category < b.category end)
  return files
end

---@return string[]
function Files.filenames()
  return vim.tbl_map(function(file) return file.file end, Files.all())
end

---@param file string
---@return Root
function Files.get(file)
  return Files.files[file]
end

---@return string[]
function Files.get_tags()
  return Files.tags
end

---@param file string
function Files.reload(file, callback)
  if file then
    local category = vim.fn.fnamemodify(file, ':t:r')
    local is_archived = config:is_archive_file(file)
    local stat = vim.loop.fs_stat(file)
    if not stat then
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
      Files.files[file] = parser.parse(lines, category, file, is_archived)
      Files._build_tags()
      if callback then
        callback()
      end
      return Files.files[file]
    end
    return utils.readfile(file, function(err, result)
      if err then return end
      Files.files[file] = parser.parse(result, category, file, is_archived)
      Files._build_tags()
      if callback then
        callback()
      end
    end)
  end
  return Files.load(callback)
end

function Files.load(callback)
  Files.files = {}
  local files = config:get_all_files()
  local files_to_process = #files
  for _, item in ipairs(files) do
    local category = vim.fn.fnamemodify(item, ':t:r')
    local is_archived = config:is_archive_file(item)
    utils.readfile(item, function(err, result)
      if err then return end
      Files.files[item] = parser.parse(result, category, item, is_archived)
      files_to_process = files_to_process - 1
      if files_to_process == 0 then
        Files._build_tags()
        if callback then
          callback()
        end
      end
    end)
  end
  return Files
end

---@return Root
function Files.get_current_file()
  local filename = vim.api.nvim_buf_get_name(0)
  local has_capture_var, is_capture = pcall(vim.api.nvim_buf_get_var, 0, 'org_capture')
  if has_capture_var and is_capture then
    return parser.parse(vim.api.nvim_buf_get_lines(0, 0, -1, true), '', filename)
  end
  local file = Files.files[filename]
  Files.files[filename] = parser.parse(vim.api.nvim_buf_get_lines(0, 0, -1, true), file.category, file.file, file.is_archive_file)
  return Files.files[filename]
end

---@return Headline|Content
function Files.get_current_item()
  local file = Files.get_current_file()
  return file:get_item(vim.fn.line('.'))
end

---@param title string
---@return Headline[]
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
---@return Headline[]
function Files.find_headlines_with_property_matching(property_name, term)
  local headlines = {}
  for _, orgfile in ipairs(Files.all()) do
    for _, headline in ipairs(orgfile:find_headlines_with_property_matching(property_name, term)) do
      table.insert(headlines, headline)
    end
  end
  return headlines
end

---@param term string
---@param no_escape boolean
---@return Headline[]
function Files.find_headlines_matching_search_term(term, no_escape)
  local headlines = {}
  for _, orgfile in ipairs(Files.all()) do
    for _, headline in ipairs(orgfile:find_headlines_matching_search_term(term, no_escape)) do
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
  if not file then return false end
  local is_same_file = filename == vim.api.nvim_buf_get_name(0)
  local cur_win = vim.api.nvim_get_current_win()
  if is_same_file then
    if action then action(file) end
    vim.cmd(':w')
    return true
  end
  vim.cmd('topleft split '..filename)
  if action then action(file) end
  vim.cmd('wq!')
  vim.api.nvim_set_current_win(cur_win)
  return true
end

function Files._build_tags()
  local tags = {}
  for _, orgfile in pairs(Files.files) do
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
    return tag:match('^'..vim.pesc(last)) and not vim.tbl_contains(parts, tag)
  end, Files.get_tags())

  return vim.tbl_map(function(tag)
    return base..tag
  end, matches)
end


return Files

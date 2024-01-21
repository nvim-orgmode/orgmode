local config = require('orgmode.config')
local File = require('orgmode.parser.file')
local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')

---@class Files
---@field loaded boolean
---@field orgfiles table
---@field tags string[]
---@field clocked_headline string|nil
local Files = {
  loaded = false,
  orgfiles = {},
  tags = {},
  clocked_headline = nil,
}

function Files.new()
  Files.loaded = false
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
        if file.clocked_headline then
          Files.set_clocked_headline(file.clocked_headline)
        end
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

function Files._set_loaded_file(filename, orgfile)
  Files.orgfiles[filename] = orgfile
  if orgfile.clocked_headline then
    Files.set_clocked_headline(orgfile.clocked_headline)
  end
end

function Files.reload(file, callback)
  if not file then
    return Files.load(callback)
  end

  local onfinish = function()
    if callback then
      callback()
    end
    Files._build_tags()
  end

  local old_file = Files.orgfiles[file]
  local new_file = Files.get(file)

  if old_file then
    Files._check_source_blocks(old_file, new_file)
    onfinish()
    return new_file
  end

  return File.load(file, function(orgfile)
    if orgfile then
      Files._set_loaded_file(file, orgfile)
      Files._check_source_blocks(old_file, orgfile)
    end
    Files.loaded = true
    onfinish()
    return orgfile
  end)
end

---@return File[]
function Files.all()
  Files.ensure_loaded()
  local valid_files = {}
  local filenames = config:get_all_files()
  for _, file in ipairs(filenames) do
    if Files.orgfiles[file] then
      table.insert(valid_files, Files.orgfiles[file])
    end
  end
  return valid_files
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
  local f = Files.orgfiles[file]
  if f then
    Files._set_loaded_file(file, f:refresh())
    return Files.orgfiles[file]
  end

  if vim.bo.filetype == 'org' and vim.fn.filereadable(file) == 0 then
    return File.from_content(vim.api.nvim_buf_get_lines(0, 0, -1, false), nil, nil, false)
  end

  return nil
end

---@return string[]
function Files.get_tags()
  return Files.tags
end

---@return File
function Files.get_current_file()
  local name = utils.current_file_path()
  local has_capture_var, is_capture = pcall(vim.api.nvim_buf_get_var, 0, 'org_capture')
  if has_capture_var and is_capture then
    return File.from_content(vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end
  return Files.get(name)
end

---@param title string
---@return Section[]
function Files.find_headlines_by_title(title, exact)
  local headlines = {}
  for _, orgfile in ipairs(Files.all()) do
    for _, headline in ipairs(orgfile:find_headlines_by_title(title, exact)) do
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
---@return Promise
function Files.update_file(filename, action)
  local file = Files.get(filename)
  if not file then
    return Promise.resolve()
  end
  local is_same_file = filename == utils.current_file_path()
  local cur_win = vim.api.nvim_get_current_win()
  if is_same_file then
    return Promise.resolve(action(file)):next(function(result)
      vim.cmd(':silent! w')
      return result
    end)
  end

  local edit_file = utils.edit_file(filename)
  edit_file.open()

  return Promise.resolve(action(file)):next(function(result)
    edit_file.close()
    return result
  end)
end

---@param term string
---@param no_escape boolean
---@param search_extra_files boolean
---@return Section
function Files.find_headlines_matching_search_term(term, no_escape, search_extra_files)
  local headlines = {}
  local ignore_archive_flag = search_extra_files
    and vim.tbl_contains(config.org_agenda_text_search_extra_files, 'agenda-archives')
  for _, orgfile in ipairs(Files.all()) do
    for _, headline in ipairs(orgfile:find_headlines_matching_search_term(term, no_escape, ignore_archive_flag)) do
      table.insert(headlines, headline)
    end
  end
  return headlines
end

---@param id? number
---@return Section?
function Files.get_closest_headline(id)
  local current_file = Files.get_current_file()
  local msg = 'Make sure there are no errors in the document'
  if not current_file then
    error({ message = string.format('Failed to parse current file. %s.', msg) })
  end
  local headline = current_file:get_closest_headline(id)
  if not headline and current_file:has_errors() then
    error({ message = string.format('Failed to parse current headline. %s.', msg) })
  end
  return headline
end

---@return TSNode
function Files.get_node_at_cursor()
  return Files.get_current_file():get_node_at_cursor()
end

---@return Section
function Files.get_clocked_headline()
  if Files.clocked_headline then
    return Files.get_headline_by_id(Files.clocked_headline)
  end
  return nil
end

---@param headline Section
function Files.set_clocked_headline(headline)
  Files.clocked_headline = headline.id
end

---@param id string
---@return Section
function Files.get_headline_by_id(id)
  local parts = vim.split(id, '####', true)
  if #parts ~= 2 then
    return nil
  end
  local file = Files.get(parts[1])
  if file then
    return file:get_closest_headline(tonumber(parts[2]))
  end
  return nil
end

function Files.get_clock_report(from, to)
  local report = {
    total = 0,
    files = {},
  }
  for name, orgfile in pairs(Files.all()) do
    local file_clocks = orgfile:get_clock_report(from, to)
    if #file_clocks.headlines > 0 then
      report.total = report.total + file_clocks.total_minutes
      report.files[name] = file_clocks.headlines
    end
  end

  return report
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
  return utils.prompt_autocomplete(arg_lead, Files.get_tags())
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

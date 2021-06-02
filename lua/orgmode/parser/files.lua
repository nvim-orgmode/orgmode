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

function Files.all()
  local files = vim.tbl_values(Files.files)
  table.sort(files, function(a, b) return a.category < b.category end)
  return files
end

function Files.filenames()
  return vim.tbl_map(function(file) return file.file end, Files.all())
end

function Files.get(file)
  return Files.files[file]
end

function Files.get_tags()
  return Files.tags
end

---@param file string
function Files.reload(file)
  if file then
    local category = vim.fn.fnamemodify(file, ':t:r')
    local is_archived = config:is_archive_file(file)
    return utils.readfile(file, function(err, result)
      if err then return end
      Files.files[file] = parser.parse(result, category, file, is_archived)
      Files._check_archive_status()
      Files._build_tags()
    end)
  end
  return Files.load()
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
        Files._check_archive_status()
        if callback then
          callback()
        end
      end
    end)
  end
  return Files
end

function Files._check_archive_status()
  local check_archived = vim.schedule_wrap(function(orgfile)
    local archive_location = orgfile:get_archive_file_location()
    local archive_orgfile = Files.get(archive_location)
    if archive_orgfile then
      archive_orgfile.is_archive_file = true
    end
  end)

  for _, orgfile in ipairs(Files.all()) do
    if not orgfile.is_archive_file then
      check_archived(orgfile)
    end
  end
end

---@return Root
function Files.get_current_file()
  local filename = vim.api.nvim_buf_get_name(0)
  local has_capture_var, is_capture = pcall(vim.api.nvim_buf_get_var, 0, 'org_capture')
  if has_capture_var and is_capture then
    return parser.parse(vim.api.nvim_buf_get_lines(0, 0, -1, true), '', filename)
  end
  local file = Files.files[filename]
  -- TODO: Figure out how to parse only parts that are changed
  Files.files[filename] = parser.parse(vim.api.nvim_buf_get_lines(0, 0, -1, true), file.category, file.file)
  return Files.files[filename]
end

function Files.get_current_item()
  local file = Files.get_current_file()
  return file:get_item(vim.fn.line('.'))
end

function Files._build_tags()
  local tags = {}
  for _, orgfile in pairs(Files.files) do
    for _, headline in ipairs(orgfile:get_opened_headlines()) do
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


return Files

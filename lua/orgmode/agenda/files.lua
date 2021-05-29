local utils = require('orgmode.utils')
local parser = require('orgmode.parser')
local config = require('orgmode.config')

---@class OrgFiles
---@field files Root[]
---@field tags string[]
local OrgFiles = {}

function OrgFiles:new()
  local opts = {}
  opts.files = {}
  opts.tags = {}
  setmetatable(opts, self)
  self.__index = self
  opts:load()
  return opts
end

function OrgFiles:all()
  local files = vim.tbl_values(self.files)
  table.sort(files, function(a, b) return a.category < b.category end)
  return files
end

function OrgFiles:filenames()
  return vim.tbl_map(function(file) return file.file end, self:all())
end

function OrgFiles:get(file)
  return self.files[file]
end

function OrgFiles:get_tags()
  return self.tags
end

---@param file string
function OrgFiles:reload(file)
  if file then
    local category = vim.fn.fnamemodify(file, ':t:r')
    return utils.readfile(file, function(err, result)
      if err then return end
      self.files[file] = parser.parse(result, category, file)
      self:_build_tags()
    end)
  end
  return self:load()
end

---@param force boolean
---@return string
function OrgFiles:load(force)
  if force then
    self.files = {}
  end
  local files = config:get_all_files()
  local files_to_process = #files
  for _, item in ipairs(files) do
    local category = vim.fn.fnamemodify(item, ':t:r')
    utils.readfile(item, function(err, result)
      if err then return end
      self.files[item] = parser.parse(result, category, item)
      files_to_process = files_to_process - 1
      if files_to_process == 0 then
        self:_build_tags()
      end
    end)
  end
  return self
end

---@return Root
function OrgFiles:get_current_file()
  local filename = vim.api.nvim_buf_get_name(0)
  local file = self.files[filename]
  -- TODO: Figure out how to parse only parts that are changed
  if vim.api.nvim_buf_get_option(0, 'modified') then
    self.files[filename] = parser.parse(vim.api.nvim_buf_get_lines(0, 0, -1, true), file.category, file.file)
  end
  return self.files[filename]
end

function OrgFiles:get_current_item()
  local file = self:get_current_file()
  return file:get_item(vim.fn.line('.'))
end

function OrgFiles:_build_tags()
  local tags = {}
  for _, orgfile in pairs(self.files) do
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
  self.tags = taglist
end


return OrgFiles

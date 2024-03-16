local Promise = require('orgmode.utils.promise')
local OrgFile = require('orgmode.files.file')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local ts_utils = require('orgmode.utils.treesitter')
local Listitem = require('orgmode.files.elements.listitem')

---@class OrgFilesOpts
---@field paths string | string[]

---@class OrgFiles
---@field paths string[]
---@field files table<string, OrgFile> table with files that are part of paths
---@field all_files table<string, OrgFile> all loaded files, no matter if they are part of paths
---@field load_state 'loading' | 'loaded' | nil
local OrgFiles = {}

---@param opts OrgFilesOpts
function OrgFiles:new(opts)
  local data = {
    paths = opts.paths or {},
    files = {},
    all_files = {},
    load_state = nil,
  }
  setmetatable(data, self)
  self.__index = self
  data:load_sync()
  return data
end

---@param force? boolean Force reload all files
---@return OrgPromise
function OrgFiles:load(force)
  if not force and self.load_state then
    if self.load_state == 'loading' then
      self:ensure_loaded()
    end
    return Promise.resolve(self.files)
  end

  self.load_state = 'loading'
  local actions = vim.tbl_map(function(filename)
    return self:load_file(filename):next(function(orgfile)
      if orgfile then
        self.files[filename] = orgfile
      end
      return orgfile
    end)
  end, self:_files())

  return Promise.all(actions):next(function()
    self.load_state = 'loaded'
    return self.files
  end)
end

function OrgFiles:get_tags()
  local tags = {}
  for _, orgfile in ipairs(self:all()) do
    if not orgfile:is_archive_file() then
      local file_tags = orgfile:get_filetags()
      if file_tags and #file_tags > 0 then
        for _, tag in ipairs(file_tags) do
          tags[tag] = 1
        end
      end
      for _, headline in ipairs(orgfile:get_headlines()) do
        local htags = headline:get_tags()
        if htags and #htags > 0 then
          for _, tag in ipairs(htags) do
            tags[tag] = 1
          end
        end
      end
    end
  end
  local taglist = vim.tbl_keys(tags)
  table.sort(taglist)
  return taglist
end

function OrgFiles:unload()
  self.files = {}
  self.all_files = {}
  self.paths = {}
  self.load_state = nil
  return self
end

function OrgFiles:get_clocked_headline()
  -- TODO: Optimize
  for _, file in ipairs(self:all()) do
    for _, headline in ipairs(file:get_headlines()) do
      if headline:is_clocked_in() then
        return headline
      end
    end
  end
  return nil
end

function OrgFiles:get_current_file()
  local filename = utils.current_file_path()
  local orgfile = self:load_file_sync(filename)
  assert(orgfile, 'Current file not found or not an org file')
  return orgfile
end

---@return OrgFile[]
function OrgFiles:all()
  self:ensure_loaded()
  local valid_files = {}
  local filenames = self:_files()
  for _, file in ipairs(filenames) do
    if self.files[file] then
      table.insert(valid_files, self.files[file])
    end
  end
  return valid_files
end

---@return string[]
function OrgFiles:filenames()
  return vim.tbl_map(function(file)
    return file.filename
  end, self:all())
end

---@return OrgPromise<OrgFile>
function OrgFiles:load_file(filename)
  local file = self.all_files[filename]
  if file then
    return file:reload()
  end

  local promise = OrgFile.load(filename):next(function(orgfile)
    if orgfile then
      self.all_files[filename] = orgfile
    end
    return orgfile
  end)

  return promise
end

---@return OrgFile | nil
function OrgFiles:load_file_sync(filename, timeout)
  return self:load_file(filename):wait(timeout)
end

function OrgFiles:get(filename)
  local file = self:load_file_sync(filename)
  assert(file, 'File ' .. filename .. ' not found or is in invalid format')
  return file
end

function OrgFiles:reload(filename)
  self:load_file(filename):next(function(orgfile)
    return orgfile
  end)
end

---@param cursor? table (1, 0) indexed base position tuple
---@return OrgHeadline
function OrgFiles:get_closest_headline(cursor)
  local file = self:load_file_sync(utils.current_file_path())
  assert(file, 'Current file is not a valid org file')
  local headline = file:get_closest_headline(cursor)
  assert(headline, 'No headline found')
  return headline
end

function OrgFiles:get_closest_listitem()
  local node = ts_utils.closest_node(ts_utils.get_node_at_cursor(), 'listitem')
  if node then
    return Listitem:new(node, self:get_current_file())
  end
  return nil
end

---@param cursor? table (1, 0) indexed base position tuple
---@return OrgHeadline | nil
function OrgFiles:get_closest_headline_or_nil(cursor)
  local file = self:load_file_sync(utils.current_file_path())
  return file and file:get_closest_headline_or_nil(cursor)
end

---@param force? boolean
---@param timeout? number
---@return OrgFiles
function OrgFiles:load_sync(force, timeout)
  return self:load(force):wait(timeout)
end

---@param title string
---@param exact? boolean
---@return OrgHeadline[]
function OrgFiles:find_headlines_by_title(title, exact)
  local headlines = {}
  for _, orgfile in ipairs(self:all()) do
    for _, headline in ipairs(orgfile:find_headlines_by_title(title, exact)) do
      table.insert(headlines, headline)
    end
  end
  return headlines
end

---@param property_name string
---@param term string
---@return OrgHeadline[]
function OrgFiles:find_headlines_with_property_matching(property_name, term)
  local headlines = {}
  for _, orgfile in ipairs(self:all()) do
    for _, headline in ipairs(orgfile:find_headlines_with_property_matching(property_name, term)) do
      table.insert(headlines, headline)
    end
  end
  return headlines
end

---@param property_name string
---@param term string
---@return OrgHeadline[]
function OrgFiles:find_headlines_with_property(property_name, term)
  local headlines = {}
  for _, orgfile in ipairs(self:all()) do
    for _, headline in ipairs(orgfile:find_headlines_with_property(property_name, term)) do
      table.insert(headlines, headline)
    end
  end
  return headlines
end

---@param property_name string
---@param term string
---@return OrgFile[]
function OrgFiles:find_files_with_property(property_name, term)
  local files = {}
  for _, orgfile in ipairs(self:all()) do
    local property = orgfile:get_property(property_name)
    if property and property:lower() == term:lower() then
      table.insert(files, orgfile)
    end
  end
  return files
end

---@param term string
---@param no_escape boolean
---@param search_extra_files boolean
---@return OrgHeadline[]
function OrgFiles:find_headlines_matching_search_term(term, no_escape, search_extra_files)
  local headlines = {}
  local ignore_archive_flag = search_extra_files
    and vim.tbl_contains(config.org_agenda_text_search_extra_files, 'agenda-archives')
  for _, orgfile in ipairs(self:all()) do
    for _, headline in ipairs(orgfile:find_headlines_matching_search_term(term, no_escape, ignore_archive_flag)) do
      table.insert(headlines, headline)
    end
  end
  return headlines
end

---@param filename string
---@param action fun(...:OrgFile):any
function OrgFiles:update_file(filename, action)
  local file = self:load_file_sync(filename)
  if not file then
    return Promise.resolve()
  end
  local is_same_file = filename == utils.current_file_path()
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

function OrgFiles:ensure_loaded()
  if self.load_state == 'loaded' then
    return true
  end
  vim.wait(5000, function()
    return self.load_state == 'loaded'
  end, 5)
end

---@private
function OrgFiles:_files()
  local all_filenames = {}
  local files = self.paths
  if not files or files == '' or (type(files) == 'table' and vim.tbl_isempty(files)) then
    return all_filenames
  end
  if type(files) ~= 'table' then
    files = { files }
  end

  local all_files = vim.tbl_map(function(file)
    return vim.tbl_map(function(path)
      return vim.fn.resolve(path)
    end, vim.fn.glob(vim.fn.fnamemodify(file, ':p'), false, true))
  end, files)

  all_files = utils.concat(vim.tbl_flatten(all_files), all_filenames, true)

  return vim.tbl_filter(function(file)
    local ext = vim.fn.fnamemodify(file, ':e')
    return ext == 'org' or ext == 'org_archive'
  end, all_files)
end

return OrgFiles

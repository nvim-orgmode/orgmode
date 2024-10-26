local Promise = require('orgmode.utils.promise')
local OrgFile = require('orgmode.files.file')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local ts_utils = require('orgmode.utils.treesitter')
local Listitem = require('orgmode.files.elements.listitem')

---@class OrgFilesOpts
---@field paths string | string[]

---@class OrgLoadFileOpts
---@field persist boolean Persist the file in the list of loaded files if it belongs to path

---@class OrgFiles
---@field paths string[]
---@field files table<string, OrgFile> table with files that are part of paths
---@field all_files table<string, OrgFile> all loaded files, no matter if they are part of paths
---@field load_state 'loading' | 'loaded' | nil
local OrgFiles = {}
OrgFiles.__index = OrgFiles

---@param opts OrgFilesOpts
function OrgFiles:new(opts)
  local data = {
    files = {},
    all_files = {},
    load_state = nil,
  }
  setmetatable(data, self)
  data.paths = self:_setup_paths(opts.paths)
  return data
end

---@param force? boolean Force reload all files
---@return OrgPromise<OrgFiles>
function OrgFiles:load(force)
  if not force and self.load_state then
    if self.load_state == 'loading' then
      self:ensure_loaded()
    end
    return Promise.resolve(self)
  end

  self.load_state = 'loading'
  return Promise.map(function(filename)
    return self:load_file(filename):next(function(orgfile)
      if orgfile then
        self.files[orgfile.filename] = orgfile
      end
      return orgfile
    end)
  end, self:_files(true), 50):next(function()
    self.load_state = 'loaded'
    return self
  end)
end

---@deprecated Use `load_file` with `persist` option instead
---@param filename string
---@return OrgPromise<OrgFile | false>
function OrgFiles:add_to_paths(filename)
  return self:load_file(filename, { persist = true })
end

---@deprecated Use `load_file_sync` with `persist` option instead
---@param filename string
---@param timeout? number
---@return OrgFile | false
function OrgFiles:add_to_paths_sync(filename, timeout)
  return self:add_to_paths(filename):wait(timeout)
end

---@return string[]
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

---@param filename string
---@param opts? OrgLoadFileOpts
---@return OrgPromise<OrgFile | false>
function OrgFiles:load_file(filename, opts)
  opts = opts or {}
  filename = vim.fn.resolve(vim.fn.fnamemodify(filename, ':p'))

  local persist_if_required = function(file)
    ---@cast file OrgFile
    if self.files[filename] or not opts.persist then
      return
    end
    local all_paths = self:_files()
    if vim.tbl_contains(all_paths, filename) then
      self.files[filename] = file
    end
  end

  local file = self.all_files[filename]
  if file then
    persist_if_required(file)
    return file:reload()
  end

  return OrgFile.load(filename):next(function(orgfile)
    if orgfile then
      persist_if_required(orgfile)
      self.all_files[filename] = orgfile
    end
    return orgfile
  end)
end

---@param filename string
---@param opts? OrgLoadFileOpts
---@return OrgFile | false
function OrgFiles:load_file_sync(filename, opts, timeout)
  return self:load_file(filename, opts):wait(timeout)
end

---@param filename string
---@return OrgFile
function OrgFiles:get(filename)
  local file = self:load_file_sync(filename)
  assert(file, 'File ' .. filename .. ' not found or is in invalid format')
  return file
end

function OrgFiles:reload(filename)
  return self:load_file(filename)
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
  local get_listitem_node = function()
    local node_at_cursor = ts_utils.get_node_at_cursor()
    if node_at_cursor and node_at_cursor:type() == 'list' then
      return node_at_cursor:named_child(0)
    end
    return ts_utils.closest_node(node_at_cursor, 'listitem')
  end

  local node = get_listitem_node()
  if node then
    return Listitem:new(node, self:get_current_file())
  end
  return nil
end

---@param cursor? table (1, 0) indexed base position tuple
---@return OrgHeadline | nil
function OrgFiles:get_closest_headline_or_nil(cursor)
  local file = self:load_file_sync(utils.current_file_path())
  return file and file:get_closest_headline_or_nil(cursor) or nil
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
  return file:update(action)
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
---@param paths string | string[] | nil
---@return string[]
function OrgFiles:_setup_paths(paths)
  if not paths or paths == '' or (type(paths) == 'table' and vim.tbl_isempty(paths)) then
    return {}
  end

  if type(paths) ~= 'table' then
    return { paths }
  end

  return paths
end

---@private
---@param skip_resolve? boolean
function OrgFiles:_files(skip_resolve)
  local all_files = vim.tbl_map(function(file)
    return vim.tbl_map(function(path)
      if skip_resolve then
        return path
      end
      return vim.fn.resolve(path)
    end, vim.fn.glob(vim.fn.fnamemodify(file, ':p'), false, true))
  end, self.paths)

  all_files = vim.tbl_flatten(all_files)

  return vim.tbl_filter(function(file)
    if not utils.is_org_file(file) then
      return false
    end

    local stat = vim.loop.fs_stat(file)
    return stat and stat.type == 'file' or false
  end, all_files)
end

return OrgFiles

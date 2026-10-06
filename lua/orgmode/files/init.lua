local Promise = require('orgmode.utils.promise')
local OrgFile = require('orgmode.files.file')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local ts_utils = require('orgmode.utils.treesitter')
local Listitem = require('orgmode.files.elements.listitem')

-- Max time (ms) to spend finding files before yielding back to the event loop
local WORK_BUDGET_MS = 5

---Sort in the same order as `vim.fn.glob()`: a path separator comes before any other character
---@param a string
---@param b string
---@return boolean
local function compare_paths(a, b)
  if vim.o.fileignorecase then
    a, b = a:upper(), b:upper()
  end
  for i = 1, math.min(#a, #b) do
    local c1, c2 = a:byte(i), b:byte(i)
    if c1 ~= c2 then
      if c1 == 47 or c2 == 47 then
        return c1 == 47
      end
      return c1 < c2
    end
  end
  return #a < #b
end

---@param path string
---@return boolean
local function is_hidden(path)
  return path:match('[^/]+$'):sub(1, 1) == '.'
end

---Same check as `vim.fn.glob()` does with 'wildignore': against the full path and the file name
---@return fun(path: string): boolean
local function wildignore_matcher()
  local regexes = {}
  local case_prefix = vim.o.fileignorecase and '\\c' or ''
  for _, pattern in ipairs(vim.split(vim.o.wildignore, ',', { trimempty = true })) do
    local ok, regex = pcall(vim.regex, case_prefix .. vim.fn.glob2regpat(pattern))
    if ok then
      table.insert(regexes, regex)
    end
  end
  return function(path)
    local name = path:match('[^/]+$')
    for _, regex in ipairs(regexes) do
      if regex:match_str(path) or regex:match_str(name) then
        return true
      end
    end
    return false
  end
end

---Find the org files matching a path from `org_agenda_files`.
---Works like `vim.fn.glob()`: hidden files and directories are only matched by a pattern that
---starts with a dot, symlinks are followed and 'wildignore' and 'fileignorecase' are respected.
---'suffixes' is not applied.
---`vim.fn.glob()` blocks the editor until it reads the whole directory, this yields while walking it.
---@async
---@param path string
---@return string[]
local function find_org_files(path)
  -- A trailing slash only matches directories
  if vim.endswith(path, '/') then
    return {}
  end
  local pattern = vim.fn.fnamemodify(vim.fs.normalize(path), ':p')
  local is_ignored = wildignore_matcher()
  -- Walk from the directory before the first wildcard, and match the rest of the pattern
  local root, rest = pattern:match('^(.-)/([^/]*[%*%?%[{].*)$')
  if not root then
    local stat = vim.uv.fs_stat(pattern)
    local is_org_file = stat and stat.type == 'file' and utils.is_org_file(pattern)
    return (is_org_file and not is_ignored(pattern)) and { pattern } or {}
  end

  root = root == '' and '/' or root
  local ignore_case = vim.o.fileignorecase
  local matcher = vim.glob.to_lpeg(ignore_case and rest:lower() or rest)
  -- `**` can match any number of directories, otherwise each segment matches one
  local depth = rest:find('**', 1, true) and 100 or #vim.split(rest, '/')
  local allow_hidden = rest:find('^%.') or rest:find('/%.')
  local skip_hidden = function(dir)
    return allow_hidden or not is_hidden(dir)
  end

  local files = {}
  local started = vim.uv.hrtime()
  for name, type in vim.fs.dir(root, { depth = depth, follow = true, skip = skip_hidden }) do
    local matches = matcher:match(ignore_case and name:lower() or name)
    if matches and (allow_hidden or not is_hidden(name)) and utils.is_org_file(name) then
      local file = vim.fs.joinpath(root, name)
      -- Symlinks are only resolved when they match
      local is_file = type == 'file' or (vim.uv.fs_stat(file) or {}).type == 'file'
      if is_file and not is_ignored(file) then
        table.insert(files, file)
      end
    end
    if (vim.uv.hrtime() - started) / 1e6 >= WORK_BUDGET_MS then
      Promise.yield():await()
      started = vim.uv.hrtime()
    end
  end

  table.sort(files, compare_paths)
  return files
end

---@class OrgFilesOpts
---@field paths string | string[]
---@field cache? boolean Store the instances to cache and retrieve it later if paths are the same

---@class OrgLoadFileOpts
---@field persist boolean Persist the file in the list of loaded files if it belongs to path

---@class OrgFiles
---@field cache? boolean
---@field cached_instances table<string, { files: OrgFiles, paths: string | string[] }>
---@field paths string[]
---@field files table<string, OrgFile> table with files that are part of paths
---@field all_files table<string, OrgFile> all loaded files, no matter if they are part of paths
---@field load_state 'loading' | 'loaded' | nil
---@field _path_cache? string[] Result of the last path discovery, valid until the next load or unload
---@field load_promise? OrgPromise<OrgFiles> Promise of the load that is currently in progress
local OrgFiles = {
  cached_instances = {},
}
OrgFiles.__index = OrgFiles

---@param opts OrgFilesOpts
---@return OrgFiles
function OrgFiles:new(opts)
  local data = {
    files = {},
    all_files = {},
    load_state = nil,
    cache = opts.cache or false,
  }
  setmetatable(data, self)
  data.paths = self:_setup_paths(opts.paths)
  return data:cache_and_return()
end

function OrgFiles:cache_and_return()
  if not self.cache then
    return self
  end
  local key = table.concat(self.paths)
  local cached = OrgFiles.cached_instances[key]
  if cached then
    return cached
  end
  OrgFiles.cached_instances[key] = self
  return self
end

---@param force? boolean Force reload all files
---@return OrgPromise<OrgFiles>
function OrgFiles:load(force)
  if not force and self.load_state then
    if self.load_state == 'loading' and self.load_promise then
      return self.load_promise
    end
    return Promise.resolve(self)
  end

  self.load_state = 'loading'
  self.load_promise = self
    :_discover_files()
    :next(function(filenames)
      return Promise.map(function(filename, index)
        return self:load_file(filename):next(function(orgfile)
          if orgfile then
            orgfile.index = index
            self.files[orgfile.filename] = orgfile
          end
          return orgfile
        end)
      end, filenames, 50)
    end)
    :next(function()
      self.load_state = 'loaded'
      self.load_promise = nil
      return self
    end)

  return self.load_promise
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
      for _, tag in ipairs(orgfile:get_tags()) do
        tags[tag] = 1
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
  self._path_cache = nil
  self.load_promise = nil
  return self
end

function OrgFiles:get_clocked_headline()
  for _, file in ipairs(self:all()) do
    if not file:is_archive_file() and file:has_running_clock_candidate() then
      for _, headline in ipairs(file:get_headlines()) do
        if headline:is_clocked_in() then
          return headline
        end
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
  for i, file in ipairs(filenames) do
    if self.files[file] then
      self.files[file].index = i
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

  ---@param file OrgFile
  ---@return OrgPromise<nil>
  local persist_if_required = function(file)
    if self.files[filename] or not opts.persist then
      return Promise.resolve()
    end
    -- Whether a file that was just created belongs to the configured paths is
    -- the one question the cache cannot answer, because the cache predates the
    -- file. Runs once per newly persisted file, not per lookup.
    return self:_discover_files():next(function(all_paths)
      if vim.tbl_contains(all_paths, filename) then
        self.files[filename] = file
      end
    end)
  end

  local file = self.all_files[filename]
  if file then
    return persist_if_required(file):next(function()
      return file:reload()
    end)
  end

  return OrgFile.load(filename):next(function(orgfile)
    if not orgfile then
      return orgfile
    end
    self.all_files[filename] = orgfile
    return persist_if_required(orgfile):next(function()
      return orgfile
    end)
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
  vim.wait(20000, function()
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

---Find the files from the configured paths again, and cache the result
---@private
---@return OrgPromise<string[]>
function OrgFiles:_discover_files()
  return Promise.async(function()
    local files = {}
    for _, path in ipairs(self.paths) do
      for _, file in ipairs(find_org_files(path)) do
        table.insert(files, vim.fn.resolve(file))
      end
    end
    self._path_cache = files
    return files
  end)
end

---@private
---@return string[]
function OrgFiles:_files()
  if not self._path_cache then
    self:_discover_files():wait()
  end
  return self._path_cache
end

return OrgFiles

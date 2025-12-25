local Promise = require('orgmode.utils.promise')
local OrgFile = require('orgmode.files.file')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local ts_utils = require('orgmode.utils.treesitter')
local Listitem = require('orgmode.files.elements.listitem')

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
---@field progressive_state? { loaded: number, total: number, loading: boolean } Progressive loading state

---@class OrgFileScanResult
---@field filename string Absolute path to the org file
---@field mtime_sec number File modification time in seconds (stat.mtime.sec)
---@field mtime_nsec number File modification time nanoseconds (stat.mtime.nsec)
---@field size number File size in bytes

---@alias OrgLoadProgressiveSortFn fun(a: OrgFileScanResult, b: OrgFileScanResult): boolean

---@class OrgLoadProgressiveOpts
---@field order_by? 'mtime'|'name'|OrgLoadProgressiveSortFn Sort order for loading files
---@field direction? 'asc'|'desc' Sort direction (default: 'desc' for mtime, 'asc' for name)
---@field current_buffer_first? boolean Prioritize current buffer file (default: true)
---@field concurrency? number Max concurrent file loads (default: 50)
---@field on_file_loaded? fun(file: OrgFile, index: number, total: number) Callback per file loaded
---@field on_complete? fun(files: OrgFile[]) Callback when all files loaded
---@field filter? fun(metadata: OrgFileScanResult): boolean Pre-load filter

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
    if self.load_state == 'loading' then
      self:ensure_loaded()
    end
    return Promise.resolve(self)
  end

  self.load_state = 'loading'
  return Promise.map(function(filename, index)
    return self:load_file(filename):next(function(orgfile)
      if orgfile then
        orgfile.index = index
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

  all_files = utils.flatten(all_files)

  return vim.tbl_filter(function(file)
    if not utils.is_org_file(file) then
      return false
    end

    local stat = vim.uv.fs_stat(file)
    return stat and stat.type == 'file' or false
  end, all_files)
end

---Scan all org files and return metadata without loading/parsing content.
---This is a fast operation that only reads file system metadata.
---Useful for change detection and ordering files by modification time.
---@return OrgFileScanResult[]
function OrgFiles:scan()
  local metadata = {}
  for _, filepath in ipairs(self:_files()) do
    local stat = vim.uv.fs_stat(filepath)
    if stat and stat.type == 'file' then
      table.insert(metadata, {
        filename = filepath,
        mtime_sec = stat.mtime.sec,
        mtime_nsec = stat.mtime.nsec,
        size = stat.size,
      })
    end
  end
  return metadata
end

---Sort metadata according to options
---@private
---@param metadata OrgFileScanResult[]
---@param opts OrgLoadProgressiveOpts
---@return OrgFileScanResult[]
function OrgFiles:_sort_metadata(metadata, opts)
  if type(opts.order_by) == 'function' then
    ---@cast opts {order_by: OrgLoadProgressiveSortFn}
    table.sort(metadata, opts.order_by)
    return metadata
  end

  local order_by = opts.order_by or 'mtime'
  local direction = opts.direction

  ---@param attr string
  ---@param desc boolean
  ---@return fun(a: OrgFileScanResult, b: OrgFileScanResult): boolean
  local function by(attr, desc)
    return desc and function(a, b)
      return a[attr] > b[attr]
    end or function(a, b)
      return a[attr] < b[attr]
    end
  end

  if order_by == 'mtime' then
    direction = direction or 'desc'
    local desc = direction == 'desc'
    table.sort(metadata, function(a, b)
      if a.mtime_sec ~= b.mtime_sec then
        return by('mtime_sec', desc)(a, b)
      end
      return by('mtime_nsec', desc)(a, b)
    end)
  elseif order_by == 'name' then
    direction = direction or 'asc'
    table.sort(metadata, by('filename', direction == 'desc'))
  end

  return metadata
end

---Load files from queue with callbacks
---@class OrgLoadQueueState
---@field total number Total number of files to load
---@field loaded_count number Number of files loaded so far
---@field loaded_files OrgFile[] Files that have been loaded
---@field batch_start_time number High-resolution timestamp when loading started
---@field last_callback_time number High-resolution timestamp of last callback

---@private
---Handle a single loaded file: update state, track timing, fire callback
---@param orgfile OrgFile|nil The loaded file (nil if loading failed)
---@param index number The index of this file in the load queue
---@param state OrgLoadQueueState Mutable state for the load operation
---@param opts OrgLoadProgressiveOpts Options including callbacks
---@return OrgFile|nil
function OrgFiles:_handle_loaded_file(orgfile, index, state, opts)
  if not orgfile then
    return orgfile
  end

  -- Capture timing to detect if callbacks batch without yielding
  local now = vim.uv.hrtime()
  orgfile._load_timing = {
    since_last_ms = (now - state.last_callback_time) / 1e6,
    since_start_ms = (now - state.batch_start_time) / 1e6,
  }
  state.last_callback_time = now

  -- Update file and state
  orgfile.index = index
  self.files[orgfile.filename] = orgfile
  state.loaded_count = state.loaded_count + 1
  table.insert(state.loaded_files, orgfile)
  self.progressive_state.loaded = state.loaded_count

  -- Fire per-file callback
  if opts.on_file_loaded then
    opts.on_file_loaded(orgfile, state.loaded_count, state.total)
  end

  return orgfile
end

---@private
---Handle completion of all file loading
---@param state OrgLoadQueueState Mutable state for the load operation
---@param opts OrgLoadProgressiveOpts Options including callbacks
---@return OrgFiles
function OrgFiles:_handle_all_loaded(state, opts)
  self.progressive_state.loading = false
  self.load_state = 'loaded'

  if opts.on_complete then
    opts.on_complete(state.loaded_files)
  end

  return self
end

---@private
---@param queue OrgFileScanResult[]
---@param opts OrgLoadProgressiveOpts
---@return OrgPromise<OrgFiles>
function OrgFiles:_load_queue(queue, opts)
  ---@type OrgLoadQueueState
  local state = {
    total = #queue,
    loaded_count = 0,
    loaded_files = {},
    batch_start_time = vim.uv.hrtime(),
  }
  state.last_callback_time = state.batch_start_time

  self.progressive_state = {
    loaded = 0,
    total = state.total,
    loading = true,
  }

  -- Handle empty queue
  if state.total == 0 then
    return Promise.resolve(self:_handle_all_loaded(state, opts))
  end

  local concurrency = opts.concurrency or 50
  local filenames = vim.tbl_map(function(m)
    return m.filename
  end, queue)

  return Promise.map(function(filename, index)
    return self:load_file(filename):next(function(orgfile)
      return self:_handle_loaded_file(orgfile, index, state, opts)
    end)
  end, filenames, concurrency):next(function()
    return self:_handle_all_loaded(state, opts)
  end)
end

---Load files progressively with configurable ordering and callbacks.
---Files are loaded in order (e.g., by mtime) with per-file callbacks for incremental updates.
---@param opts? OrgLoadProgressiveOpts
---@return OrgPromise<OrgFiles>
function OrgFiles:load_progressive(opts)
  opts = vim.tbl_extend('force', {
    order_by = 'mtime',
    direction = 'desc',
    current_buffer_first = true,
    concurrency = 50,
  }, opts or {})

  local metadata = self:scan()

  -- Apply filter if provided
  if opts.filter then
    metadata = vim.tbl_filter(opts.filter, metadata)
  end

  -- Sort metadata
  self:_sort_metadata(metadata, opts)

  -- Move current buffer to front if requested
  if opts.current_buffer_first then
    local current_file = vim.fn.resolve(vim.fn.expand('%:p'))
    if current_file and current_file ~= '' then
      local current_idx = nil
      for i, m in ipairs(metadata) do
        if m.filename == current_file then
          current_idx = i
          break
        end
      end
      if current_idx and current_idx > 1 then
        local current = table.remove(metadata, current_idx)
        table.insert(metadata, 1, current)
      end
    end
  end

  self.load_state = 'loading'
  return self:_load_queue(metadata, opts)
end

---Get the current progressive loading state
---@return { loaded: number, total: number, loading: boolean }?
function OrgFiles:get_load_progress()
  return self.progressive_state
end

return OrgFiles

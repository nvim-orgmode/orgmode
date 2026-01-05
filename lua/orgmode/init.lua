_G.orgmode = _G.orgmode or {}
_G.Org = _G.Org or {}
---@type Org | nil
local instance = nil

local emit = require('orgmode.utils.emit')

local auto_instance_keys = {
  files = true,
  agenda = true,
  capture = true,
  clock = true,
  org_mappings = true,
  notifications = true,
  completion = true,
  links = true,
}

---@class Org
---@field initialized boolean
---@field setup_called boolean
---@field files OrgFiles
---@field highlighter OrgHighlighter
---@field agenda OrgAgenda
---@field capture OrgCapture
---@field clock OrgClock
---@field completion OrgCompletion
---@field org_mappings OrgMappings
---@field notifications OrgNotifications
---@field links OrgLinks
---@field private _file_loaded_callbacks fun(file: OrgFile, index: number, total: number)[]
---@field private _files_loaded_callbacks fun(files: OrgFile[])[]
local Org = {}
setmetatable(Org, {
  __index = function(tbl, key)
    if auto_instance_keys[key] then
      Org.instance()
    end
    return rawget(tbl, key)
  end,
})

function Org:new()
  require('orgmode.org.global')(self)
  self.initialized = false
  self.setup_called = false
  self._file_loaded_callbacks = {}
  self._files_loaded_callbacks = {}
  self:setup_autocmds()
  require('orgmode.config'):setup_ts_predicates()
  return self
end

---Show profiling results (delegates to Profiler module)
function Org.profiling()
  require('orgmode.utils.profiler').show()
end

function Org:init()
  if self.initialized then
    return
  end

  emit.profile('start', 'init', 'START')

  local config = require('orgmode.config')
  emit.profile('mark', 'init', 'require config')

  require('orgmode.events').init()
  emit.profile('mark', 'init', 'events.init()')

  self.highlighter = require('orgmode.colors.highlighter'):new()
  emit.profile('mark', 'init', 'highlighter:new()')

  require('orgmode.colors.highlights').define_highlights()
  emit.profile('mark', 'init', 'define_highlights()')

  self.files = require('orgmode.files'):new({
    paths = config.org_agenda_files,
  })
  emit.profile('mark', 'init', 'OrgFiles:new()')

  emit.profile('mark', 'init', string.format('org_async_loading = %s', tostring(config.org_async_loading)))

  -- Callback wrappers to fire registered callbacks
  local function on_file_loaded(file, index, total)
    for _, callback in ipairs(self._file_loaded_callbacks) do
      callback(file, index, total)
    end
  end

  local function on_complete(files)
    -- Emit batch-level profiling events
    local progress = self.files:get_load_progress()
    if progress and progress.batch_timings then
      emit.profile('start', 'files', string.format('START (%d files)', progress.total), { total = progress.total })

      for _, batch in ipairs(progress.batch_timings) do
        local mem_delta = batch.mem_after_kb and batch.mem_before_kb and (batch.mem_after_kb - batch.mem_before_kb)
          or nil
        local batch_name = batch.batch_num == 1 and 'open buffers' or 'remaining'
        emit.profile(
          'mark',
          'files',
          string.format('batch %d (%s): %d files', batch.batch_num, batch_name, batch.files_count),
          {
            total_ms = batch.cumulative_ms,
            duration_ms = batch.duration_ms,
            yield_gap_ms = batch.gap_from_prev_ms,
            total_bytes = batch.total_bytes,
            mem_delta_kb = mem_delta,
          }
        )
      end

      -- Calculate final wall time from the last batch
      local last_batch = progress.batch_timings[#progress.batch_timings]
      local final_wall_ms = last_batch and last_batch.cumulative_ms or 0

      emit.profile('complete', 'files', 'COMPLETE', {
        total = progress.total,
        total_ms = final_wall_ms,
        duration_ms = 0, -- COMPLETE is just a marker, no additional duration
      })
    end

    -- Fire registered callbacks
    for _, callback in ipairs(self._files_loaded_callbacks) do
      callback(files)
    end
  end

  if config.org_async_loading then
    -- Defer to next event loop to allow buffer display first
    vim.schedule(function()
      self.files:request_load({
        async = true,
        on_file_loaded = on_file_loaded,
        on_complete = on_complete,
      })
    end)
    emit.profile('mark', 'init', 'scheduled request_load (async)')
  else
    self.files:request_load_sync()
    emit.profile('mark', 'init', 'request_load_sync COMPLETE')
    on_complete(self.files:all())
  end

  self.links = require('orgmode.org.links'):new({ files = self.files })
  emit.profile('mark', 'init', 'links:new()')

  self.agenda = require('orgmode.agenda'):new({
    files = self.files,
    highlighter = self.highlighter,
    links = self.links,
  })
  emit.profile('mark', 'init', 'agenda:new()')

  self.capture = require('orgmode.capture'):new({
    files = self.files,
  })
  emit.profile('mark', 'init', 'capture:new()')

  self.completion = require('orgmode.org.autocompletion'):new({ files = self.files, links = self.links })
  emit.profile('mark', 'init', 'completion:new()')

  self.org_mappings = require('orgmode.org.mappings'):new({
    capture = self.capture,
    agenda = self.agenda,
    files = self.files,
    links = self.links,
    completion = self.completion,
  })
  emit.profile('mark', 'init', 'org_mappings:new()')

  self.clock = require('orgmode.clock'):new({
    files = self.files,
  })
  emit.profile('mark', 'init', 'clock:new()')

  self.statusline_debounced = require('orgmode.utils').debounce('statusline', function()
    return self.clock:get_statusline()
  end, 300)
  emit.profile('mark', 'init', 'statusline setup')

  self.initialized = true
  emit.profile('complete', 'init', 'COMPLETE')
end

---@param file? string
function Org:reload(file)
  self:init()
  return self.files:reload(file)
end

function Org:setup_autocmds()
  local org_augroup = vim.api.nvim_create_augroup('orgmode_nvim', { clear = true })
  vim.api.nvim_create_autocmd('BufWinEnter', {
    pattern = { '*.org', '*.org_archive' },
    group = org_augroup,
    callback = function(event)
      if not vim.bo[event.buf].filetype or vim.bo[event.buf].filetype == '' then
        vim.bo[event.buf].filetype = 'org'
      end
    end,
  })
  vim.api.nvim_create_autocmd('BufWritePost', {
    pattern = { '*.org', '*.org_archive' },
    group = org_augroup,
    callback = function(event)
      self:reload(vim.fn.fnamemodify(event.file, ':p'))
    end,
  })
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'org',
    group = org_augroup,
    callback = function()
      -- Defer to let buffer display first, then initialize
      local file = vim.fn.expand('<afile>:p')
      vim.schedule(function()
        emit.profile('start', 'filetype', 'START')
        self:reload(file):next(function()
          emit.profile('complete', 'filetype', 'reload() complete')
        end)
      end)
    end,
  })
  vim.api.nvim_create_autocmd('ColorScheme', {
    pattern = '*',
    group = org_augroup,
    callback = function()
      if self.initialized then
        require('orgmode.colors.highlights').define_highlights()
      end
    end,
  })
end

---@param opts? OrgConfigOpts
---@return Org
function Org.setup(opts)
  opts = opts or {}
  local config = require('orgmode.config'):extend(opts)
  config:install_grammar()

  -- Initialize profiler based on config
  require('orgmode.utils.profiler').setup({
    enabled = config.profiling and config.profiling.enabled or false,
  })

  instance = Org:new()
  instance.setup_called = true

  -- Register notifications via callback - no separate load() call!
  -- Notifications will start after files are loaded by Org:init()
  if config.notifications.enabled and #vim.api.nvim_list_uis() > 0 then
    instance:on_files_loaded(function()
      -- Defer to let the UI settle after file loading completes
      vim.defer_fn(function()
        instance.notifications = require('orgmode.notifications')
          :new({
            files = Org.files,
          })
          :start_timer()
      end, 1000)
    end)
  end

  vim.defer_fn(function()
    config:setup_mappings('global')
  end, 1)

  return instance
end

---@private
---@param cmd string
---@param opts string
function Org._set_dot_repeat(cmd, opts)
  local repeat_action = { string.format("'%s'", cmd) }
  if opts then
    table.insert(repeat_action, string.format("'%s'", opts))
  end
  vim.cmd(
    string.format(
      [[silent! call repeat#set("\<cmd>lua require('orgmode').action(%s)\<CR>")]],
      table.concat(repeat_action, ',')
    )
  )
end

---@param cmd string
---@param opts? any
function Org.action(cmd, opts)
  local parts = vim.split(cmd, '.', { plain = true })
  if #parts < 2 then
    return
  end
  local org = Org.instance()
  local item = nil
  for i = 1, #parts - 1 do
    local part = parts[i]
    if not item then
      item = org[part]
    else
      item = item[part]
    end
  end
  if item and item[parts[#parts]] then
    local method = item[parts[#parts]]
    local success, result = pcall(method, item, opts)
    if not success then
      if result.message then
        return require('orgmode.utils').echo_error(result.message)
      end
      if type(result) == 'string' then
        return require('orgmode.utils').echo_error(result)
      end
    end
    Org._set_dot_repeat(cmd, opts)
    return result
  end
end

function Org.cron(opts)
  local ok, result = pcall(function()
    local config = require('orgmode.config'):extend(opts or {})
    if not config.notifications.cron_enabled then
      return vim.cmd([[qa!]])
    end
    Org.files:load_sync(true, 20000)
    instance.notifications = require('orgmode.notifications')
      :new({
        files = Org.files,
      })
      :cron()
  end)

  if not ok then
    require('orgmode.utils').system_notification('Orgmode failed to run cron: ' .. tostring(result))
    return vim.cmd([[qa!]])
  end
end

function Org.instance()
  if not instance then
    instance = Org:new()
  end
  instance:init()
  return instance
end

function Org.destroy()
  if instance then
    instance = nil
    collectgarbage()
  end
end

--- Scan all org files and return metadata without full parsing.
--- This is a fast operation that only reads file system metadata (mtime, size).
---@return OrgFileScanResult[]
function Org:scan_files()
  self:init()
  return self.files:scan()
end

--- Load files progressively with callbacks for incremental updates.
--- Files are sorted by mtime (newest first) by default.
---@param opts? OrgLoadProgressiveOpts
---@return OrgPromise<OrgFile[]>
function Org:load_files(opts)
  self:init()
  opts = opts or {}

  -- Wrap callbacks to also fire registered event callbacks
  local original_on_file_loaded = opts.on_file_loaded
  local original_on_complete = opts.on_complete

  opts.on_file_loaded = function(file, index, total)
    -- Fire registered callbacks
    for _, callback in ipairs(self._file_loaded_callbacks) do
      callback(file, index, total)
    end
    -- Fire original callback if provided
    if original_on_file_loaded then
      original_on_file_loaded(file, index, total)
    end
  end

  opts.on_complete = function(files)
    -- Fire registered callbacks
    for _, callback in ipairs(self._files_loaded_callbacks) do
      callback(files)
    end
    -- Fire original callback if provided
    if original_on_complete then
      original_on_complete(files)
    end
  end

  return self.files:load_progressive(opts)
end

--- Check if files have been loaded.
---@return boolean
function Org:is_files_loaded()
  if not self.initialized then
    return false
  end
  local progress = self.files:get_load_progress()
  if not progress then
    return false
  end
  return not progress.loading and progress.loaded == progress.total
end

--- Get current file loading progress.
---@return { loaded: number, total: number, loading: boolean }?
function Org:get_files_progress()
  if not self.initialized then
    return nil
  end
  return self.files:get_load_progress()
end

--- Register a callback to be called when each file is loaded.
---@param callback fun(file: OrgFile, index: number, total: number)
function Org:on_file_loaded(callback)
  table.insert(self._file_loaded_callbacks, callback)
end

--- Register a callback to be called when all files are loaded.
---@param callback fun(files: OrgFile[])
function Org:on_files_loaded(callback)
  table.insert(self._files_loaded_callbacks, callback)
end

function Org.is_setup_called()
  if not instance then
    return false
  end
  return instance.setup_called
end

function _G.orgmode.statusline()
  if not instance or not instance.initialized then
    return ''
  end
  return instance.statusline_debounced() or ''
end

return Org

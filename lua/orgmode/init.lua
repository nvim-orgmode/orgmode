_G.orgmode = _G.orgmode or {}
_G.Org = _G.Org or {}
---@type Org | nil
local instance = nil

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
---@field buffers OrgBuffers
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

-- Profiling data storage
local profiling_data = {
  init = {},
  setup = {},
  filetype_reload = {},
  progressive_loading = {},
  clock_init = {},
}

local function create_profiler(category)
  local entries = {}
  local start = vim.uv.hrtime()
  local last = start

  return {
    mark = function(label)
      local now = vim.uv.hrtime()
      table.insert(entries, {
        label = label,
        total_ms = (now - start) / 1e6,
        delta_ms = (now - last) / 1e6,
      })
      last = now
    end,
    finish = function()
      profiling_data[category] = entries
    end,
  }
end

-- Expose create_profiler for use by other modules (clock, files, etc.)
Org.create_profiler = create_profiler

---Show profiling results in a floating window
function Org.profiling()
  local lines = { '# Orgmode Profiling Results', '' }

  local function add_section(title, entries)
    if #entries == 0 then
      return
    end
    table.insert(lines, '## ' .. title)
    table.insert(lines, '')
    table.insert(lines, string.format('  %-40s %10s %10s', 'Step', 'Total', 'Delta'))
    table.insert(lines, string.format('  %-40s %10s %10s', string.rep('-', 40), '----------', '----------'))

    for _, entry in ipairs(entries) do
      local delta_indicator = ''
      if entry.delta_ms > 100 then
        delta_indicator = ' ⚠️'
      elseif entry.delta_ms > 1000 then
        delta_indicator = ' 🔴'
      end
      table.insert(
        lines,
        string.format('  %-40s %8.1f ms %8.1f ms%s', entry.label, entry.total_ms, entry.delta_ms, delta_indicator)
      )
    end
    table.insert(lines, '')
  end

  add_section('Org:init()', profiling_data.init)
  add_section('Org.setup()', profiling_data.setup)
  add_section('FileType reload (deferred)', profiling_data.filetype_reload)
  add_section('Progressive loading (deferred)', profiling_data.progressive_loading)
  add_section('Clock:init (deferred)', profiling_data.clock_init)

  local has_data = #profiling_data.init > 0
    or #profiling_data.setup > 0
    or #profiling_data.filetype_reload > 0
    or #profiling_data.progressive_loading > 0
    or #profiling_data.clock_init > 0

  if not has_data then
    table.insert(lines, 'No profiling data available yet.')
    table.insert(lines, 'Open an org file first to collect timing data.')
  end

  -- Create floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].modifiable = false

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.min(#lines + 2, vim.o.lines - 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Org Profiling ',
    title_pos = 'center',
  })

  -- Close on q or <Esc>
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

function Org:init()
  if self.initialized then
    return
  end

  self.buffers = require('orgmode.state.buffers').init()

  local profiler = create_profiler('init')
  profiler.mark('START')

  local config = require('orgmode.config')
  profiler.mark('require config')

  require('orgmode.events').init()
  profiler.mark('events.init()')

  self.highlighter = require('orgmode.colors.highlighter'):new()
  profiler.mark('highlighter:new()')

  require('orgmode.colors.highlights').define_highlights()
  profiler.mark('define_highlights()')

  self.files = require('orgmode.files'):new({
    local config = require('orgmode.config')
    paths = config.org_agenda_files,
  })
  profiler.mark('OrgFiles:new()')

  profiler.mark(string.format('org_async_loading = %s', tostring(config.org_async_loading)))

  -- Load files: async (non-blocking) or sync (blocking) based on config
  if config.org_async_loading then
    -- Defer progressive loading to next event loop to allow buffer display first
    vim.schedule(function()
      local load_profiler = create_profiler('progressive_loading')
      load_profiler.mark('START')
      self:load_files({
        current_buffer_first = true,
        on_file_loaded = function(file, index, total)
          local timing = file._load_timing or {}
          local gap = timing.since_last_ms or 0
          -- Show gap between callbacks - if all ~0ms, callbacks are batching without yielding
          load_profiler.mark(
            string.format('file %d/%d: %s (gap: %.1fms)', index, total, vim.fn.fnamemodify(file.filename, ':t'), gap)
          )
        end,
        on_complete = function()
          load_profiler.mark('COMPLETE')
          load_profiler.finish()
        end,
      })
    end)
    profiler.mark('scheduled load_files (deferred)')
  else
    self.files:load_sync(true, 20000)
    profiler.mark('load_sync COMPLETED (blocking)')
  end

  self.links = require('orgmode.org.links'):new({ files = self.files })
  profiler.mark('links:new()')

  self.agenda = require('orgmode.agenda'):new({
    files = self.files,
    highlighter = self.highlighter,
    links = self.links,
  })
  profiler.mark('agenda:new()')

  self.capture = require('orgmode.capture'):new({
    files = self.files,
  })
  profiler.mark('capture:new()')

  self.completion = require('orgmode.org.autocompletion'):new({ files = self.files, links = self.links })
  profiler.mark('completion:new()')

  self.org_mappings = require('orgmode.org.mappings'):new({
    capture = self.capture,
    agenda = self.agenda,
    files = self.files,
    links = self.links,
    completion = self.completion,
  })
  profiler.mark('org_mappings:new()')

  self.clock = require('orgmode.clock'):new({
    files = self.files,
  })
  profiler.mark('clock:new()')

  self.statusline_debounced = require('orgmode.utils').debounce('statusline', function()
    return self.clock:get_statusline()
  end, 300)
  profiler.mark('statusline setup')

  self.initialized = true
  profiler.mark('COMPLETE')
  profiler.finish()
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
        local profiler = create_profiler('filetype_reload')
        profiler.mark('START')
        self:reload(file)
        profiler.mark('reload() complete')
        profiler.finish()
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

  vim.api.nvim_create_autocmd({ 'BufNew' }, {
    pattern = { '*.org', '*.org_archive' },
    group = org_augroup,
    callback = function(event)
      if self.buffers then
        self.buffers.add(event.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWipeout', {
    pattern = { '*.org', '*.org_archive' },
    group = org_augroup,
    callback = function(event)
      if self.buffers then
        self.buffers.remove(event.buf)
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
  instance = Org:new()
  instance.setup_called = true
  vim.defer_fn(function()
    if config.notifications.enabled and #vim.api.nvim_list_uis() > 0 then
      Org.files:load():next(vim.schedule_wrap(function()
        instance.notifications = require('orgmode.notifications')
          :new({
            files = Org.files,
          })
          :start_timer()
      end))
    end
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

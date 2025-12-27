---@class OrgProfiler
---@field private _enabled boolean
---@field private _sessions table<string, OrgProfilerSession>
---@field private _section_config table<string, OrgProfilerSectionConfig>
---@field private _event_subscriptions table
local Profiler = {
  _enabled = false,
  _sessions = {},
  _section_config = {},
  _event_subscriptions = {},
}

---@class OrgProfilerSession
---@field category string Session category (e.g., 'init', 'files', 'plugin:my-plugin')
---@field start_time number High-resolution start timestamp (vim.uv.hrtime)
---@field entries OrgProfilerEntry[] Collected timing entries

---@class OrgProfilerEntry
---@field label string Human-readable label
---@field timestamp number High-resolution timestamp
---@field total_ms number Milliseconds since session start
---@field delta_ms number Milliseconds since previous entry
---@field payload? table Optional event payload data

---@class OrgProfilerSectionConfig
---@field title string Display title
---@field order number Sort order (lower = earlier)
---@field format 'simple'|'batch' Display format
---@field description? string Hover/help text

-- Pre-registered core sections
local DEFAULT_SECTIONS = {
  init = {
    title = 'Org:init()',
    order = 1,
    format = 'simple',
    description = 'Core initialization timing',
  },
  files = {
    title = 'Progressive Loading',
    order = 2,
    format = 'batch',
    description = 'File loading with batch timing',
  },
  clock = {
    title = 'Clock Lazy Init',
    order = 3,
    format = 'simple',
    description = 'Clock lazy initialization',
  },
  filetype = {
    title = 'FileType Reload',
    order = 4,
    format = 'simple',
    description = 'FileType autocmd reload timing',
  },
}

---@param opts? { enabled?: boolean }
function Profiler.setup(opts)
  opts = opts or {}
  Profiler._enabled = opts.enabled or false
  Profiler._sessions = {}
  Profiler._section_config = vim.deepcopy(DEFAULT_SECTIONS)
  Profiler._event_subscriptions = {}

  if Profiler._enabled then
    Profiler._subscribe_to_events()
  end
end

---@return boolean
function Profiler.is_enabled()
  return Profiler._enabled
end

---@return table<string, OrgProfilerSession>
function Profiler.get_data()
  return Profiler._sessions
end

function Profiler.clear()
  Profiler._sessions = {}
end

---Register a custom profiling section
---@param category string Unique category (recommend 'plugin:<name>')
---@param opts OrgProfilerSectionConfig
---@return boolean success
function Profiler.register_section(category, opts)
  if Profiler._section_config[category] then
    return false -- already registered
  end
  Profiler._section_config[category] = {
    title = opts.title or category,
    order = opts.order or 1000, -- plugins sort after core
    format = opts.format or 'simple',
    description = opts.description,
  }
  return true
end

---@class OrgProfilerHandle
---@field mark fun(label: string, payload?: table) Record a timing mark
---@field finish fun() Complete the session and store data
---@field cancel fun() Cancel the session without storing

---Create a new profiling session for custom code
---@param category string Unique category name (recommend: 'plugin:<name>')
---@return OrgProfilerHandle
function Profiler.create_session(category)
  if not Profiler._enabled then
    -- Return no-op handle when profiling disabled
    return {
      mark = function() end,
      finish = function() end,
      cancel = function() end,
    }
  end

  Profiler._ensure_section(category)

  local start_time = vim.uv.hrtime()
  local entries = {}
  local last_time = start_time
  local cancelled = false

  return {
    mark = function(label, payload)
      if cancelled then
        return
      end
      local now = vim.uv.hrtime()
      table.insert(entries, {
        label = label,
        timestamp = now,
        total_ms = (now - start_time) / 1e6,
        delta_ms = (now - last_time) / 1e6,
        payload = payload,
      })
      last_time = now
    end,
    finish = function()
      if cancelled then
        return
      end
      Profiler._sessions[category] = {
        category = category,
        start_time = start_time,
        entries = entries,
      }
    end,
    cancel = function()
      cancelled = true
    end,
  }
end

---@private
---@param category string
function Profiler._ensure_section(category)
  if not Profiler._section_config[category] then
    -- Auto-create for unregistered categories
    Profiler._section_config[category] = {
      title = category:gsub('^plugin:', 'Plugin: '):gsub('^%l', string.upper),
      order = 9999, -- sort last
      format = 'simple',
    }
  end
end

---Subscribe to profiling events (called during setup if enabled)
---@private
function Profiler._subscribe_to_events()
  local EventManager = require('orgmode.events')
  local ProfilingEvent = require('orgmode.events.types.profiling_event')
  EventManager.listen(ProfilingEvent, Profiler._on_profiling_event)
end

---Handle a profiling event
---@private
---@param event OrgProfilingEvent
function Profiler._on_profiling_event(event)
  if not Profiler._enabled then
    return
  end

  local category = event.category
  Profiler._ensure_section(category)

  if event.action == 'start' then
    -- Initialize a new session
    Profiler._sessions[category] = {
      category = category,
      start_time = vim.uv.hrtime(),
      entries = {},
    }
    -- Add the start entry
    local session = Profiler._sessions[category]
    table.insert(session.entries, {
      label = event.label,
      timestamp = session.start_time,
      total_ms = 0,
      delta_ms = 0,
      payload = event.payload,
    })
  elseif event.action == 'mark' or event.action == 'complete' then
    local session = Profiler._sessions[category]
    if not session then
      -- Session wasn't started, create it now
      session = {
        category = category,
        start_time = vim.uv.hrtime(),
        entries = {},
      }
      Profiler._sessions[category] = session
    end

    local now = vim.uv.hrtime()
    local last_entry = session.entries[#session.entries]
    local last_time = last_entry and last_entry.timestamp or session.start_time

    table.insert(session.entries, {
      label = event.label,
      timestamp = now,
      total_ms = (now - session.start_time) / 1e6,
      delta_ms = (now - last_time) / 1e6,
      payload = event.payload,
    })
  end
end

---Format milliseconds for display
---@private
---@param ms number
---@return string
local function format_ms(ms)
  if ms >= 1000 then
    return string.format('%7.2f s', ms / 1000)
  else
    return string.format('%7.2f ms', ms)
  end
end

---Add a simple section to output lines
---@private
---@param lines string[]
---@param title string
---@param entries OrgProfilerEntry[]
local function add_simple_section(lines, title, entries)
  if #entries == 0 then
    return
  end

  table.insert(lines, string.format('## %s', title))
  table.insert(lines, '')
  table.insert(lines, string.format('  %-40s %10s %10s', 'Step', 'Total', 'Delta'))
  table.insert(lines, string.format('  %s %s %s', string.rep('-', 40), string.rep('-', 10), string.rep('-', 10)))

  for _, entry in ipairs(entries) do
    local payload_str = ''
    if entry.payload then
      local parts = {}
      for k, v in pairs(entry.payload) do
        table.insert(parts, string.format('%s=%s', k, tostring(v)))
      end
      if #parts > 0 then
        payload_str = '  ' .. table.concat(parts, ', ')
      end
    end
    table.insert(
      lines,
      string.format('  %-40s %s %s%s', entry.label, format_ms(entry.total_ms), format_ms(entry.delta_ms), payload_str)
    )
  end
  table.insert(lines, '')
end

---Format memory delta for display with consistent width
---@private
---@param mem_delta_kb number
---@return string
local function format_mem(mem_delta_kb)
  return string.format('%+7.1f MB', mem_delta_kb / 1024)
end

---Add a batch section to output lines (for file loading with memory/yield info)
---@private
---@param lines string[]
---@param title string
---@param entries OrgProfilerEntry[]
local function add_batch_section(lines, title, entries)
  if #entries == 0 then
    return
  end

  table.insert(lines, string.format('## %s', title))
  table.insert(lines, '')

  -- Check if any entry has batch-specific payload
  local has_batch_data = false
  for _, entry in ipairs(entries) do
    if entry.payload and (entry.payload.mem_delta_kb or entry.payload.yield_gap_ms) then
      has_batch_data = true
      break
    end
  end

  if not has_batch_data then
    -- Simple format without batch data
    table.insert(lines, string.format('  %-40s %10s %10s', 'Step', 'Total', 'Delta'))
    table.insert(lines, string.format('  %s %s %s', string.rep('-', 40), string.rep('-', 10), string.rep('-', 10)))
    for _, entry in ipairs(entries) do
      table.insert(
        lines,
        string.format('  %-40s %s %s', entry.label, format_ms(entry.total_ms), format_ms(entry.delta_ms))
      )
    end
    table.insert(lines, '')
    return
  end

  -- Batch format: first pass to collect data and calculate column widths
  local headers = { 'Step', 'Since Start', 'Batch Time', 'Idle', 'Mem Δ' }
  local rows = {}
  local async_scheduling_row = nil

  for _, entry in ipairs(entries) do
    local payload = entry.payload or {}
    local idle = payload.yield_gap_ms
    local mem_delta = payload.mem_delta_kb
    local since_start = payload.total_ms or entry.total_ms
    local batch_time = payload.duration_ms or entry.delta_ms

    -- Detect async scheduling delay before first batch
    if not async_scheduling_row and batch_time and since_start and batch_time > 0 then
      local scheduling_delay = since_start - batch_time - (idle or 0)
      if scheduling_delay > 1 then
        async_scheduling_row = {
          '(async scheduling)',
          format_ms(scheduling_delay),
          '',
          '',
          '',
        }
      end
    end

    -- Only show values if meaningful (> 0)
    local show_batch_time = batch_time and batch_time > 0
    local show_idle = idle and idle > 0
    local show_mem = mem_delta and mem_delta ~= 0

    table.insert(rows, {
      entry.label,
      format_ms(since_start),
      show_batch_time and format_ms(batch_time) or '',
      show_idle and format_ms(idle) or '',
      show_mem and format_mem(mem_delta) or '',
    })
  end

  -- Insert async scheduling row after first entry (START) if present
  if async_scheduling_row and #rows > 0 then
    table.insert(rows, 2, async_scheduling_row)
  end

  -- Calculate column widths: max of header and all content
  local col_widths = {}
  for i, header in ipairs(headers) do
    col_widths[i] = #header
  end
  for _, row in ipairs(rows) do
    for i, cell in ipairs(row) do
      col_widths[i] = math.max(col_widths[i], #cell)
    end
  end

  -- Build format string with calculated widths
  local header_fmt = '  %-' .. col_widths[1] .. 's'
  local row_fmt = '  %-' .. col_widths[1] .. 's'
  local dash_parts = { string.rep('-', col_widths[1]) }
  for i = 2, #col_widths do
    header_fmt = header_fmt .. ' %' .. col_widths[i] .. 's'
    row_fmt = row_fmt .. ' %' .. col_widths[i] .. 's'
    table.insert(dash_parts, string.rep('-', col_widths[i]))
  end

  -- Output header
  table.insert(lines, string.format(header_fmt, unpack(headers)))
  table.insert(lines, '  ' .. table.concat(dash_parts, ' '))

  -- Output rows
  for _, row in ipairs(rows) do
    table.insert(lines, string.format(row_fmt, unpack(row)))
  end
  table.insert(lines, '')
end

---Display profiling results in floating window
function Profiler.show()
  local lines = { '# Orgmode Profiling Results', '' }

  -- Get sorted section categories
  local categories = {}
  for category, _ in pairs(Profiler._sessions) do
    table.insert(categories, category)
  end
  table.sort(categories, function(a, b)
    local order_a = Profiler._section_config[a] and Profiler._section_config[a].order or 9999
    local order_b = Profiler._section_config[b] and Profiler._section_config[b].order or 9999
    if order_a ~= order_b then
      return order_a < order_b
    end
    return a < b
  end)

  local has_data = false
  for _, category in ipairs(categories) do
    local session = Profiler._sessions[category]
    if session and #session.entries > 0 then
      has_data = true
      local config = Profiler._section_config[category] or { title = category, format = 'simple' }

      if config.format == 'batch' then
        add_batch_section(lines, config.title, session.entries)
      else
        add_simple_section(lines, config.title, session.entries)
      end
    end
  end

  if not has_data then
    table.insert(lines, 'No profiling data available yet.')
    table.insert(lines, 'Open an org file first to collect timing data.')
  end

  -- Create floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buf })

  local width = math.min(120, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Orgmode Profiling ',
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

return Profiler

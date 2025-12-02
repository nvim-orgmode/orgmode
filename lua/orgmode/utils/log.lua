---@class OrgLogger
local Log = {
  levels = {
    debug = 1,
    info = 2,
    warn = 3,
    error = 4,
    off = 5,
  },
}

local logfilename = vim.fs.joinpath(vim.fn.stdpath('log') --[[@as string]], 'orgmode.log')
local logfile, openerr

local function format_message(label, ...)
  local items = { ... }
  local msg = ''
  if #items > 1 then
    msg = string.format(items[1], unpack(items, 2))
  else
    msg = tostring(items[1])
  end

  return ('[%s][%s] %s\n'):format(os.date('%Y-%m-%d %H:%M:%S'), label:upper(), msg)
end

local function format_func(level, ...)
  if not Log.levels[Org.log_level] then
    error(string.format('[orgmode] Invalid log level: %s', level))
  end
  if Log.levels[level] < Log.levels[Org.log_level] then
    return nil
  end

  return format_message(level, ...)
end

local function open_logfile()
  -- Try to open file only once
  if logfile then
    return true
  end
  if openerr then
    return false
  end

  logfile, openerr = io.open(logfilename, 'a+')
  if not logfile then
    local err_msg = string.format('Failed to open Orgmode log file: %s', openerr)
    vim.notify(err_msg, vim.log.levels.ERROR)
    return false
  end

  local log_info = vim.uv.fs_stat(logfilename)
  if log_info and log_info.size > 1e9 then
    local warn_msg =
      string.format('Orgmode client log is large (%d MB): %s', log_info.size / (1000 * 1000), logfilename)
    vim.notify(warn_msg)
  end

  -- Start message for logging
  logfile:write(('-'):rep(80) .. '\n')
  logfile:write(format_message('start', 'Orgmode logger initialized'))
  return true
end

---@param level OrgLogLevel
local function create_logger(level)
  return function(...)
    local argc = select('#', ...)
    if argc == 0 then
      return true
    end
    local message = format_func(level, ...)
    if not message then
      return
    end

    if not open_logfile() then
      return false
    end
    assert(logfile)
    logfile:write(message)
    logfile:flush()
  end
end

Log.debug = create_logger('debug')
Log.info = create_logger('info')
Log.warn = create_logger('warn')
Log.error = create_logger('error')

return Log

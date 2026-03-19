local Date = require('orgmode.objects.date')
local config = require('orgmode.config')
local utils = require('orgmode.utils')
local NotificationPopup = require('orgmode.notifications.notification_popup')
local current_file_path = string.sub(debug.getinfo(1, 'S').source, 2)
local root_path = vim.fn.fnamemodify(current_file_path, ':p:h:h:h:h')

---@class OrgNotificationsCacheEntry
---@field mtime number
---@field mtime_sec number
---@field changedtick number
---@field headlines { headline: OrgHeadline, dates: OrgDate[] }[]

---@class OrgNotifications
---@field timer table
---@field files OrgFiles
---@field _file_cache table<string, OrgNotificationsCacheEntry>
local Notifications = {}

---@param opts { files: OrgFiles }
function Notifications:new(opts)
  local data = {
    timer = nil,
    files = opts.files,
    _file_cache = {},
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Notifications:start_timer()
  self:stop_timer()
  self.timer = vim.uv.new_timer()
  self:notify(Date.now())
  self.timer:start(
    (60 - os.date('%S')) * 1000,
    60000,
    vim.schedule_wrap(function()
      self:notify(Date.now())
    end)
  )
end

function Notifications:stop_timer()
  if self.timer then
    self.timer:close()
    self.timer = nil
  end
end

---@private
---Run get_tasks as a coroutine, processing file batches across event loop iterations
---@param time OrgDate
---@param callback fun(tasks: table[])
function Notifications:_get_tasks_async(time, callback)
  local co = coroutine.create(function()
    return self:get_tasks(time)
  end)

  local function step()
    local ok, result = coroutine.resume(co)
    if not ok then
      vim.notify('[orgmode] notification error: ' .. tostring(result), vim.log.levels.ERROR)
      return
    end
    if coroutine.status(co) == 'dead' then
      callback(result)
    else
      vim.schedule(step)
    end
  end

  step()
end

---@param time OrgDate
function Notifications:notify(time)
  self:_get_tasks_async(time, function(tasks)
    if type(config.notifications.notifier) == 'function' then
      return config.notifications.notifier(tasks)
    end

    local result = {}
    for _, task in ipairs(tasks) do
      utils.concat(result, {
        string.format('# %s (%s)', task.category, task.humanized_duration),
        string.format('%s %s %s', string.rep('*', task.level), task.todo or '', task.title),
        string.format('%s: <%s>', task.type, task.time:to_string()),
      })
    end

    if not vim.tbl_isempty(result) then
      NotificationPopup:new({ content = result, border = config.win_border })
    end
  end)
end

function Notifications:cron()
  self:_get_tasks_async(Date.now(), function(tasks)
    if type(config.notifications.cron_notifier) == 'function' then
      config.notifications.cron_notifier(tasks)
    else
      self:_cron_notifier(tasks)
    end
    vim.cmd([[qall!]])
  end)
end

---@param tasks table[]
function Notifications:_cron_notifier(tasks)
  for _, task in ipairs(tasks) do
    local title = string.format('%s (%s)', task.category, task.humanized_duration)
    local subtitle = string.format('%s %s %s', string.rep('*', task.level), task.todo or '', task.title)
    local date = string.format('%s: %s', task.type, task.time:to_string())

    if vim.fn.executable('notify-send') == 1 then
      vim.system({
        'notify-send',
        ('--icon=%s/assets/nvim-orgmode-small.png'):format(root_path),
        '--app-name=orgmode',
        title,
        string.format('%s\n%s', subtitle, date),
      })
    end

    if vim.fn.executable('terminal-notifier') == 1 then
      vim.system({ 'terminal-notifier', '-title', title, '-subtitle', subtitle, '-message', date })
    end
  end
end

---@private
---Check if the cache entry for a file is still valid
---@param orgfile OrgFile
---@return boolean
function Notifications:_is_cache_valid(orgfile)
  local cached = self._file_cache[orgfile.filename]
  if not cached then
    return false
  end
  return cached.mtime == orgfile.metadata.mtime
    and cached.mtime_sec == orgfile.metadata.mtime_sec
    and cached.changedtick == orgfile.metadata.changedtick
end

---@private
---Get cached headline data for a file, rebuilding the cache if the file has changed
---@param orgfile OrgFile
---@return { headline: OrgHeadline, dates: OrgDate[] }[]
function Notifications:_get_cached_headlines(orgfile)
  if self:_is_cache_valid(orgfile) then
    return self._file_cache[orgfile.filename].headlines
  end

  local headline_data = {}
  for _, headline in ipairs(orgfile:get_opened_unfinished_headlines()) do
    local dates = headline:get_deadline_and_scheduled_dates()
    if #dates > 0 then
      table.insert(headline_data, { headline = headline, dates = dates })
    end
  end

  self._file_cache[orgfile.filename] = {
    mtime = orgfile.metadata.mtime,
    mtime_sec = orgfile.metadata.mtime_sec,
    changedtick = orgfile.metadata.changedtick,
    headlines = headline_data,
  }

  return headline_data
end

---@param time OrgDate
function Notifications:get_tasks(time)
  local tasks = {}
  local orgfiles = self.files:all()
  local file_idx = 1
  local batch_size = 3

  local function process_batch()
    local batch_end = math.min(file_idx + batch_size - 1, #orgfiles)
    for i = file_idx, batch_end do
      local orgfile = orgfiles[i]
      local headline_data = self:_get_cached_headlines(orgfile)
      for _, entry in ipairs(headline_data) do
        for _, date in ipairs(entry.dates) do
          local reminders = self:_check_reminders(date, time)
          -- only build task objects when reminders match
          if #reminders > 0 then
            local headline = entry.headline
            for _, reminder in ipairs(reminders) do
              table.insert(tasks, {
                file = orgfile.filename,
                todo = headline:get_todo(),
                category = headline:get_category(),
                priority = headline:get_priority(),
                title = headline:get_title(),
                level = headline:get_level(),
                tags = headline:get_tags(),
                original_time = date,
                time = reminder.time,
                reminder_type = reminder.reminder_type,
                minutes = reminder.minutes,
                humanized_duration = utils.humanize_minutes(reminder.minutes),
                type = date.type,
                range = headline:get_range(),
              })
            end
          end
        end
      end
    end
    file_idx = batch_end + 1
  end

  -- process files in batches, yielding between batches to avoid blocking the editor
  local _, is_main = coroutine.running()
  while file_idx <= #orgfiles do
    process_batch()
    if not is_main and file_idx <= #orgfiles then
      coroutine.yield()
    end
  end

  return tasks
end

---@param date OrgDate - date to check
---@param time OrgDate - time to check agains
---@returns table|nil
function Notifications:_check_reminders(date, time)
  local result = {}
  local notifications = config.notifications or {}
  if date:is_deadline() and not notifications.deadline_reminder then
    return result
  end
  if date:is_scheduled() and not notifications.scheduled_reminder then
    return result
  end

  if notifications.repeater_reminder_time and date:get_repeater() then
    local repeater_time = date:apply_repeater_until(time)
    local times = utils.ensure_array(notifications.repeater_reminder_time)
    local minutes = repeater_time:diff(time, 'minute')
    if not date:is_same(repeater_time) and vim.tbl_contains(times, minutes) then
      table.insert(result, {
        reminder_type = 'repeater',
        time = repeater_time:without_adjustments(),
        minutes = minutes,
      })
    end
  end

  if notifications.deadline_warning_reminder_time and date:is_deadline() and date:get_negative_adjustment() then
    local warning_time = date:with_negative_adjustment()
    local times = utils.ensure_array(notifications.deadline_warning_reminder_time)
    local minutes = warning_time:diff(time, 'minute')
    if vim.tbl_contains(times, minutes) then
      local real_minutes = date:diff(time, 'minute')
      table.insert(result, {
        reminder_type = 'warning',
        time = date:without_adjustments(),
        minutes = real_minutes,
      })
    end
  end

  if notifications.reminder_time then
    local times = utils.ensure_array(notifications.reminder_time)
    local minutes = date:diff(time, 'minute')
    if vim.tbl_contains(times, minutes) then
      table.insert(result, {
        reminder_type = 'time',
        time = date:without_adjustments(),
        minutes = minutes,
      })
    end
  end

  return result
end

return Notifications

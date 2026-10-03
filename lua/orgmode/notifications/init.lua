local Date = require('orgmode.objects.date')
local config = require('orgmode.config')
local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')
local NotificationPopup = require('orgmode.notifications.notification_popup')
local current_file_path = string.sub(debug.getinfo(1, 'S').source, 2)
local root_path = vim.fn.fnamemodify(current_file_path, ':p:h:h:h:h')

---@class OrgNotifications
---@field timer uv.uv_timer_t | nil
---@field files OrgFiles
---@field private running boolean
---@field private queued_time? OrgDate Time to check once the running check is done
local Notifications = {}

-- The first check parses every agenda file, give the editor time to finish starting up
local FIRST_CHECK_DELAY_MS = 2000

---@param opts { files: OrgFiles }
function Notifications:new(opts)
  local data = {
    timer = nil,
    files = opts.files,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function Notifications:start_timer()
  self:stop_timer()
  local timer = vim.uv.new_timer()
  self.timer = timer
  -- Taken now, so the minute in which the editor started is checked even if the delay crosses into the next one
  local start_time = Date.now()
  vim.defer_fn(function()
    if self.timer == timer then
      self:notify(start_time)
    end
  end, FIRST_CHECK_DELAY_MS)
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

---@param time OrgDate
---@return OrgPromise<nil>
function Notifications:notify(time)
  if self.running then
    -- Check this minute too once the running check is done, instead of skipping it
    self.queued_time = time
    return Promise.resolve()
  end
  self.running = true

  local run_queued = function()
    local queued_time = self.queued_time
    self.queued_time = nil
    if queued_time then
      return self:notify(queued_time)
    end
  end

  return self
    :get_tasks_async(time)
    :next(function(tasks)
      self.running = false
      self:_show(tasks)
      return run_queued()
    end)
    :catch(function(err)
      self.running = false
      vim.notify('Orgmode notifications failed: ' .. tostring(err), vim.log.levels.ERROR)
      return run_queued()
    end)
end

---@private
---@param tasks table[]
function Notifications:_show(tasks)
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
end

function Notifications:cron()
  return self
    :get_tasks_async(Date.now())
    :next(function(tasks)
      if type(config.notifications.cron_notifier) == 'function' then
        config.notifications.cron_notifier(tasks)
      else
        self:_cron_notifier(tasks)
      end
    end)
    :finally(function()
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
---@param orgfile OrgFile
---@param headline OrgHeadline
---@param time OrgDate
---@param tasks table[]
function Notifications:_collect_headline_tasks(orgfile, headline, time, tasks)
  for _, date in ipairs(headline:get_deadline_and_scheduled_dates()) do
    for _, reminder in ipairs(self:_check_reminders(date, time)) do
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

---Blocking version. Prefer `get_tasks_async`.
---@param time OrgDate
---@return table[]
function Notifications:get_tasks(time)
  local tasks = {}
  for _, orgfile in ipairs(self.files:all()) do
    for _, headline in ipairs(orgfile:get_opened_unfinished_headlines()) do
      self:_collect_headline_tasks(orgfile, headline, time, tasks)
    end
  end
  return tasks
end

-- Max time (ms) to work before yielding back to the event loop
local WORK_BUDGET_MS = 5

---Non-blocking version. Loads files without blocking and yields to the event loop
---whenever the work budget is spent.
---@param time OrgDate
---@return OrgPromise<table[]>
function Notifications:get_tasks_async(time)
  return Promise.async(function()
    self.files:load():await()
    local tasks = {}
    local started = vim.uv.hrtime()
    local function maybe_yield()
      if (vim.uv.hrtime() - started) / 1e6 >= WORK_BUDGET_MS then
        Promise.yield():await()
        started = vim.uv.hrtime()
      end
    end

    for _, orgfile in ipairs(self.files:all()) do
      if not orgfile:is_archive_file() then
        -- Parsing a big file at once would block the editor
        orgfile:parse_async():await()
        maybe_yield()
        -- Same filter as `get_opened_unfinished_headlines`, done here so it can be split up
        for _, headline in ipairs(orgfile:get_headlines()) do
          if not headline:is_archived() and not headline:is_done() then
            self:_collect_headline_tasks(orgfile, headline, time, tasks)
          end
          maybe_yield()
        end
      end
      maybe_yield()
    end
    return tasks
  end)
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

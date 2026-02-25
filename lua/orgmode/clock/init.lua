local Duration = require('orgmode.objects.duration')
local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')
local Input = require('orgmode.ui.input')

---@class OrgClock
---@field files OrgFiles
---@field clocked_headline OrgHeadline|nil
---@field private _clocked_headline_searched boolean Lazy init flag: only search when needed
local Clock = {}

function Clock:new(opts)
  local data = {
    files = opts.files,
    clocked_headline = nil,
    _clocked_headline_searched = false,
  }
  setmetatable(data, self)
  self.__index = self

  data:_schedule_async_preload()

  return data
end

---Schedule async preload of clocked headline after files are loaded
function Clock:_schedule_async_preload()
  vim.schedule(function()
    if self.files.load_state == 'loaded' then
      return self:_search_clocked_headline_async()
    end

    require('orgmode'):on_files_loaded(function()
      vim.defer_fn(function()
        self:_search_clocked_headline_async()
      end, 1)
    end)
  end)
end

-- Async search for clocked headline - non-blocking background search
function Clock:_search_clocked_headline_async()
  if self._clocked_headline_searched then
    return
  end

  -- Don't search if files aren't loaded yet
  if self.files.load_state ~= 'loaded' then
    return
  end

  self._clocked_headline_searched = true

  self.files:get_clocked_headline_async():next(function(headline)
    if headline and headline:is_clocked_in() then
      self.clocked_headline = headline
    end
  end)
end

-- Sync fallback for when immediate access is needed (e.g., clock operations before preload completes)
function Clock:_ensure_clocked_headline_searched()
  if self._clocked_headline_searched then
    return
  end

  -- Don't search if files aren't loaded yet
  if self.files.load_state ~= 'loaded' then
    return
  end

  self._clocked_headline_searched = true

  local emit = require('orgmode.utils.emit')
  emit.profile('start', 'clock', 'START (sync fallback)')

  local last_clocked_headline = self.files:get_clocked_headline()
  if profiler then
    profiler.mark('get_clocked_headline() complete')
  end

  if last_clocked_headline and last_clocked_headline:is_clocked_in() then
    self.clocked_headline = last_clocked_headline
  end

  if profiler then
    profiler.mark('COMPLETE')
    profiler.finish()
  end
end

function Clock:update_clocked_headline()
  local last_clocked_headline = self.files:get_clocked_headline()
  if last_clocked_headline and last_clocked_headline:is_clocked_in() then
    self.clocked_headline = last_clocked_headline
  end
end

function Clock:has_clocked_headline()
  -- Ensure we've done the initial search
  self:_ensure_clocked_headline_searched()
  self:update_clocked_headline()
  return self.clocked_headline ~= nil
end

function Clock:org_clock_in()
  self:update_clocked_headline()
  local item = self.files:get_closest_headline()
  if item:is_clocked_in() then
    return utils.echo_info(string.format('Clock continues in "%s"', item:get_title()))
  end

  local promise = Promise.resolve()

  if self.clocked_headline and self.clocked_headline:is_clocked_in() then
    local file = self.clocked_headline.file
    promise = file:update(function()
      local clocked_item = file:reload_sync():get_closest_headline({ self.clocked_headline:get_range().start_line, 0 })
      clocked_item:clock_out()
    end)
  end

  return promise:next(function()
    item:clock_in()
    self.clocked_headline = item
  end)
end

function Clock:org_clock_out()
  self:update_clocked_headline()
  if not self.clocked_headline or not self.clocked_headline:is_clocked_in() then
    return
  end

  self.clocked_headline:clock_out()
  self.clocked_headline = nil
end

function Clock:org_clock_cancel()
  self:update_clocked_headline()
  if not self.clocked_headline or not self.clocked_headline:is_clocked_in() then
    return utils.echo_info('No active clock')
  end

  self.clocked_headline:cancel_active_clock()
  self.clocked_headline = nil
  utils.echo_info('Clock canceled')
end

function Clock:org_clock_goto()
  self:update_clocked_headline()
  if not self.clocked_headline then
    return utils.echo_info('No active or recent clock task')
  end

  if not self.clocked_headline:is_clocked_in() then
    utils.echo_info('No running clock, this is the most recently clocked task')
  end

  utils.goto_headline(self.clocked_headline)
end

function Clock:org_set_effort()
  local item = self.files:get_closest_headline()
  -- TODO: Add Effort_ALL property as autocompletion
  local current_effort = item:get_property('Effort')
  return Input.open('Effort: ', current_effort or ''):next(function(effort)
    if not effort then
      return false
    end
    local duration = Duration.parse(effort)
    if duration == nil then
      return utils.echo_error('Invalid duration format: ' .. effort)
    end
    item:set_property('Effort', effort)
    return item
  end)
end

function Clock:get_statusline()
  -- Lazy init: search for clocked headline on first statusline call
  self:_ensure_clocked_headline_searched()

  if not self.clocked_headline or not self.clocked_headline:is_clocked_in() then
    return ''
  end

  local effort = self.clocked_headline:get_property('effort', false)
  local total = self.clocked_headline:get_logbook():get_total_with_active():to_string()
  if effort then
    return string.format('(Org) [%s/%s] (%s)', total, effort or '', self.clocked_headline:get_title())
  end
  return string.format('(Org) [%s] (%s)', total, self.clocked_headline:get_title())
end

return Clock

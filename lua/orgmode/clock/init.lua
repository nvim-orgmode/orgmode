local Duration = require('orgmode.objects.duration')
local utils = require('orgmode.utils')
local Promise = require('orgmode.utils.promise')

---@class OrgClock
---@field files OrgFiles
---@field clocked_headline OrgHeadline|nil
local Clock = {}

function Clock:new(opts)
  local data = {
    files = opts.files,
    clocked_headline = nil,
  }
  setmetatable(data, self)
  self.__index = self
  data:init()
  return data
end

-- When first loading, check if there are active clocks
function Clock:init()
  local last_clocked_headline = self.files:get_clocked_headline()
  if last_clocked_headline and last_clocked_headline:is_clocked_in() then
    self.clocked_headline = last_clocked_headline
  end
end

function Clock:has_clocked_headline()
  return self.clocked_headline ~= nil
end

function Clock:org_clock_in()
  local item = self.files:get_closest_headline()
  if item:is_clocked_in() then
    return utils.echo_info(string.format('Clock continues in "%s"', item:get_title()))
  end

  local promise = Promise.resolve()

  if self.clocked_headline and self.clocked_headline:is_clocked_in() then
    local filename = self.clocked_headline.file.filename
    promise = self.files:update_file(filename, function()
      local clocked_item =
        self.files:get(filename):get_closest_headline({ self.clocked_headline:get_range().start_line, 0 })
      clocked_item:clock_out()
    end)
  end

  return promise:next(function()
    item:clock_in()
    self.clocked_headline = item
  end)
end

function Clock:org_clock_out()
  if not self.clocked_headline or not self.clocked_headline:is_clocked_in() then
    return
  end

  self.clocked_headline:clock_out()
  self.clocked_headline = nil
end

function Clock:org_clock_cancel()
  if not self.clocked_headline or not self.clocked_headline:is_clocked_in() then
    return utils.echo_info('No active clock')
  end

  self.clocked_headline:cancel_active_clock()
  self.clocked_headline = nil
  utils.echo_info('Clock canceled')
end

function Clock:org_clock_goto()
  if not self.clocked_headline then
    return utils.echo_info('No active or recent clock task')
  end

  if not self.clocked_headline:is_clocked_in() then
    utils.echo_info('No running clock, this is the most recently clocked task')
  end

  if utils.current_file_path() ~= self.clocked_headline.file then
    vim.cmd('edit ' .. vim.fn.fnameescape(self.clocked_headline.file.filename))
  end
  vim.fn.cursor({ self.clocked_headline:get_range().start_line, 1 })
end

function Clock:org_set_effort()
  local item = self.files:get_closest_headline()
  -- TODO: Add Effort_ALL property as autocompletion
  local current_effort = item:get_property('Effort')
  local effort = vim.fn.OrgmodeInput('Effort: ', current_effort or '')
  local duration = Duration.parse(effort)
  if duration == nil then
    return utils.echo_error('Invalid duration format: ' .. effort)
  end
  item:set_property('Effort', effort)
end

function Clock:get_statusline()
  if not self.clocked_headline or not self.clocked_headline:is_clocked_in() then
    return ''
  end

  local effort = self.clocked_headline:get_property('effort')
  local total = self.clocked_headline:get_logbook():get_total_with_active():to_string()
  if effort then
    return string.format('(Org) [%s/%s] (%s)', total, effort or '', self.clocked_headline:get_title())
  end
  return string.format('(Org) [%s] (%s)', total, self.clocked_headline:get_title())
end

return Clock

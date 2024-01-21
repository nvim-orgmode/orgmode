local Files = require('orgmode.parser.files')
local utils = require('orgmode.utils')
local ts_org = require('orgmode.treesitter')
local OrgPosition = require('orgmode.api.position')
local PriorityState = require('orgmode.objects.priority_state')
local Date = require('orgmode.objects.date')
local Calendar = require('orgmode.objects.calendar')
local Promise = require('orgmode.utils.promise')

---@class OrgHeadline
---@field title string headline title without todo keyword, tags and priority. Ex. `* TODO I am a headline  :SOMETAG:` returns `I am a headline`
---@field line string full headline line
---@field level number headline level (number of asterisks). Example: 1
---@field todo_value? string todo keyword of the headline (Example: TODO, DONE)
---@field todo_type? string | "'TODO'" | "'DONE'" | "''"
---@field tags string[] List of own tags
---@field deadline Date|nil
---@field scheduled Date|nil
---@field properties table<string, string> Table containing all properties. All keys are lowercased
---@field closed Date|nil
---@field dates Date[] List of all dates that are not "plan" dates
---@field position Range
---@field all_tags string[] List of all tags (own + inherited)
---@field file OrgFile
---@field parent OrgHeadline|nil
---@field priority string|nil
---@field is_archived boolean headline marked with the `:ARCHIVE:` tag
---@field headlines OrgHeadline[]
---@field private _section Section
---@field private _index number
local OrgHeadline = {}

---@private
function OrgHeadline:_new(opts)
  local data = {}
  data.file = opts.file
  data.todo_type = opts.todo_type
  data.todo_value = opts.todo_value
  data.title = opts.title
  data.line = opts.line
  data.level = opts.level
  data.category = opts.category
  data.position = opts.position
  data.tags = opts.tags
  data.all_tags = opts.all_tags
  data.priority = opts.priority
  data.deadline = opts.deadline
  data.properties = opts.properties
  data.scheduled = opts.scheduled
  data.closed = opts.closed
  data.dates = opts.dates
  data.is_archived = opts.is_archived
  data.parent = opts.parent
  data.headlines = opts.headlines or {}
  data._section = opts._section
  data._index = opts._index

  setmetatable(data, self)
  self.__index = self
  return data
end

---@param section Section
---@param index number
---@private
function OrgHeadline._build_from_internal_section(section, index)
  return OrgHeadline:_new({
    title = section.title,
    line = section.line,
    level = section.level,
    todo_type = section.todo_keyword.type,
    todo_value = section.todo_keyword.value,
    all_tags = { unpack(section.tags) },
    tags = section:get_own_tags(),
    position = OrgPosition:_build_from_internal_range(section.range),
    properties = section:get_properties(),
    deadline = section:get_deadline_date(),
    scheduled = section:get_scheduled_date(),
    closed = section:get_closed_date(),
    dates = vim.tbl_filter(function(date)
      return date:is_none()
    end, section.dates),
    priority = section.priority,
    is_archived = section:is_archived(),
    _section = section,
    _index = index,
  })
end

--- Return updated version of headline
---@return OrgHeadline
function OrgHeadline:reload()
  local file = self.file:reload()
  return file.headlines[self._index]
end

--- Set tags on the headline. This replaces all current tags with provided ones
---@param tags string[]
---@return Promise
function OrgHeadline:set_tags(tags)
  return self:_do_action(function()
    local headline = ts_org.closest_headline()
    return headline:set_tags(string.format(':%s:', table.concat(tags, ':')))
  end)
end

--- Increase priority on a headline
---@return Promise
function OrgHeadline:priority_up()
  return self:_do_action(function()
    local headline = ts_org.closest_headline()
    local _, current_priority = headline:priority()
    local priority_state = PriorityState:new(current_priority)
    return headline:set_priority(priority_state:increase())
  end)
end

--- Decrease priority on a headline
---@return Promise
function OrgHeadline:priority_down()
  return self:_do_action(function()
    local headline = ts_org.closest_headline()
    local _, current_priority = headline:priority()
    local priority_state = PriorityState:new(current_priority)
    return headline:set_priority(priority_state:decrease())
  end)
end

--- Set specific priority on a headline. Empty string clears the priority
---@param priority string
---@return Promise
function OrgHeadline:set_priority(priority)
  return self:_do_action(function()
    local headline = ts_org.closest_headline()
    return headline:set_priority(priority)
  end)
end

--- Set deadline date
---@param date? Date|string|nil If ommited, opens the datepicker. Empty string removes the date. String must follow org date convention (YYYY-MM-DD HH:mm...)
---@return Promise
function OrgHeadline:set_deadline(date)
  return self:_do_action(function()
    local headline = ts_org.closest_headline()
    local deadline_date = headline:deadline()
    if not date then
      return Calendar.new({ date = deadline_date or Date.today(), clearable = true })
        .open()
        :next(function(new_date, cleared)
          if cleared then
            return headline:remove_deadline_date()
          end
          if not new_date then
            return
          end
          return headline:set_deadline_date(new_date)
        end)
    end

    if type(date) == 'string' then
      if date == '' then
        return headline:remove_deadline_date()
      end
      local date_instance = Date.from_string(date)
      if date_instance then
        return headline:set_deadline_date(date_instance)
      end
      error('Invalid string format for deadline date')
    end

    if Date.is_date_instance(date) then
      return headline:set_deadline_date(date)
    end

    error('Invalid argument to set_deadline')
  end)
end

--- Set scheduled date
---@param date? Date|string|nil If ommited, opens the datepicker. Empty string removes the date. String must follow org date convention (YYYY-MM-DD HH:mm...)
---@return Promise
function OrgHeadline:set_scheduled(date)
  return self:_do_action(function()
    local headline = ts_org.closest_headline()
    local scheduled_date = headline:scheduled()
    if not date then
      return Calendar.new({ date = scheduled_date or Date.today(), clearable = true })
        .open()
        :next(function(new_date, cleared)
          if cleared then
            return headline:remove_scheduled_date()
          end
          if not new_date then
            return
          end
          return headline:set_scheduled_date(new_date)
        end)
    end

    if type(date) == 'string' then
      if date == '' then
        return headline:remove_scheduled_date()
      end
      local date_instance = Date.from_string(date)
      if date_instance then
        return headline:set_scheduled_date(date_instance)
      end
      error('Invalid string format for schedule date')
    end

    if Date.is_date_instance(date) then
      return headline:set_scheduled_date(date)
    end

    error('Invalid argument to set_scheduled')
  end)
end

--- Set property on a headline
---@param key string
---@param value string
function OrgHeadline:set_property(key, value)
  return self:_do_action(function()
    local headline = ts_org.closest_headline()
    return headline:set_property(key, value)
  end)
end

--- Get headline property
---@param key string
---@return string | nil
function OrgHeadline:get_property(key)
  return self.properties[key:lower()]
end

--- Get headline id or create a new one if it doesn't exist
--- @return string
function OrgHeadline:id_get_or_create()
  local id = self:get_property('id')
  if id then
    return id
  end
  local org_id = require('orgmode.org.id').new()
  self:set_property('ID', org_id)
  return org_id
end

---@param action function
---@private
function OrgHeadline:_do_action(action)
  return Files.update_file(self.file.filename, function()
    local view = vim.fn.winsaveview()
    vim.fn.cursor({ self.position.start_line, 0 })
    return Promise.resolve(action()):next(function()
      vim.fn.winrestview(view)
      return self:reload()
    end)
  end)
end

return OrgHeadline

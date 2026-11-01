local OrgPosition = require('orgmode.api.position')
local config = require('orgmode.config')
local PriorityState = require('orgmode.objects.priority_state')
local Date = require('orgmode.objects.date')
local Calendar = require('orgmode.objects.calendar')
local Promise = require('orgmode.utils.promise')
local org = require('orgmode')

local mark_namespace = vim.api.nvim_create_namespace('orgmode.api.headline')

---Each call on a handle finds its headline again: by its ID if it has one, otherwise by its line while the
---file is unchanged, and else by its outline path and headline line. A handle without an ID raises an error
---when its own headline line or a parent's title changed since it was loaded, instead of acting on a guess
---(|OrgHeadline:reload| returns nil). The failed call changes nothing. To recover, load again with
---|OrgApi.load|, find the headline among the new handles and repeat the call.
---@class OrgApiHeadline
---@field title string headline title without todo keyword, tags and priority. Ex. `* TODO I am a headline  :SOMETAG:` returns `I am a headline`
---@field line string full headline line
---@field level number headline level (number of asterisks). Example: 1
---@field todo_value? string todo keyword of the headline (Example: TODO, DONE)
---@field todo_type? 'TODO' | 'DONE' | ''
---@field tags string[] List of own tags
---@field deadline OrgDate|nil
---@field scheduled OrgDate|nil
---@field properties table<string, string> Table containing all properties. All keys are lowercased
---@field closed OrgDate|nil
---@field dates OrgDate[] List of all dates that are not "plan" dates
---@field position OrgRange
---@field all_tags string[] List of all tags (own + inherited)
---@field file OrgApiFile
---@field parent OrgApiHeadline|nil
---@field priority string|nil
---@field is_archived boolean headline marked with the `:ARCHIVE:` tag
---@field headlines OrgApiHeadline[]
---@field private _section OrgHeadline
---@field private _file_version number version of the file the handle was built from
---@field private _outline_key string outline path and line of the headline when the handle was built
---@field private _outline_key_unique boolean no other headline had the same outline key when the handle was built
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
  data._file_version = opts._file_version
  data._outline_key = opts._outline_key

  setmetatable(data, self)
  self.__index = self
  return data
end

---@param section OrgHeadline
---@private
function OrgHeadline._build_from_internal_headline(section)
  local todo, _, type = section:get_todo()
  local properties = section:get_own_properties()
  return OrgHeadline:_new({
    title = section:get_title(),
    line = section:get_headline_line_content(),
    level = section:get_level(),
    todo_type = type,
    todo_value = todo,
    all_tags = section:get_tags(),
    tags = section:get_own_tags(),
    ---@diagnostic disable-next-line: invisible
    position = OrgPosition:_build_from_internal_range(section:get_range()),
    properties = properties,
    deadline = section:get_deadline_date(),
    scheduled = section:get_scheduled_date(),
    closed = section:get_closed_date(),
    dates = vim.tbl_filter(function(date)
      return date:is_none()
    end, section:get_all_dates()),
    priority = section:get_priority(),
    is_archived = section:is_archived(),
    _section = section,
    _file_version = section.file.version,
    _outline_key = section:get_outline_key(),
  })
end

--- Return updated version of headline, or nil when the headline can no longer be found
---@return OrgApiHeadline|nil
function OrgHeadline:reload()
  local file = self.file:reload()
  ---@diagnostic disable-next-line: invisible
  local section = self:_find_section_or_nil(file._file)
  return section and file:get_headline_on_line(section:get_range().start_line)
end

--- Set tags on the headline. This replaces all current tags with provided ones
---@param tags string[]
---@return OrgPromise
function OrgHeadline:set_tags(tags)
  return self:_do_action(function()
    local headline = org.files:get_closest_headline()
    headline:set_tags(string.format(':%s:', table.concat(tags, ':')))
  end)
end

--- Increase priority on a headline
---@return OrgPromise
function OrgHeadline:priority_up()
  return self:_do_action(function()
    local headline = org.files:get_closest_headline()
    local current_priority = headline:get_priority()
    local prio_range = config:get_priority_range()
    local start_with_default = config.org_priority_start_cycle_with_default
    local priority_state = PriorityState:new(current_priority, prio_range, start_with_default)
    return headline:set_priority(priority_state:increase())
  end)
end

--- Decrease priority on a headline
---@return OrgPromise
function OrgHeadline:priority_down()
  return self:_do_action(function()
    local headline = org.files:get_closest_headline()
    local current_priority = headline:get_priority()
    local prio_range = config:get_priority_range()
    local start_with_default = config.org_priority_start_cycle_with_default
    local priority_state = PriorityState:new(current_priority, prio_range, start_with_default)
    return headline:set_priority(priority_state:decrease())
  end)
end

--- Set specific priority on a headline. Empty string clears the priority
---@param priority string
---@return OrgPromise
function OrgHeadline:set_priority(priority)
  return self:_do_action(function()
    local headline = org.files:get_closest_headline()
    return headline:set_priority(priority)
  end)
end

--- Set deadline date
---@param date? OrgDate|string|nil If ommited, opens the datepicker. Empty string removes the date. String must follow org date convention (YYYY-MM-DD HH:mm...)
---@return OrgPromise
function OrgHeadline:set_deadline(date)
  return self:_do_action(function()
    local headline = org.files:get_closest_headline()
    local deadline_date = headline:get_deadline_date()
    if not date then
      return Calendar.new({ date = deadline_date or Date.today(), clearable = true, title = 'Set deadline' })
        :open()
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
      error('Invalid string format for deadline date', 0)
    end

    if Date.is_date_instance(date) then
      return headline:set_deadline_date(date)
    end

    error('Invalid argument to set_deadline', 0)
  end)
end

--- Set scheduled date
---@param date? OrgDate|string|nil If ommited, opens the datepicker. Empty string removes the date. String must follow org date convention (YYYY-MM-DD HH:mm...)
---@return OrgPromise
function OrgHeadline:set_scheduled(date)
  return self:_do_action(function()
    local headline = org.files:get_closest_headline()
    local scheduled_date = headline:get_scheduled_date()
    if not date then
      return Calendar.new({ date = scheduled_date or Date.today(), clearable = true, title = 'Set schedule' })
        :open()
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
      error('Invalid string format for schedule date', 0)
    end

    if Date.is_date_instance(date) then
      return headline:set_scheduled_date(date)
    end

    error('Invalid argument to set_scheduled', 0)
  end)
end

--- Set property on a headline. Setting value to nil removes the property
---@param key string
---@param value? string
function OrgHeadline:set_property(key, value)
  local new_id = nil
  if key:lower() == 'id' then
    new_id = value ~= '' and value or false
  end
  return self:_do_action(function()
    local headline = org.files:get_closest_headline()
    return headline:set_property(key, value)
  end, new_id)
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
  -- The headline may have gotten an ID after this handle was built
  id = self:_find_section(org.files:get(self.file.filename)):get_property('id', false)
  if id then
    self.properties.id = id
    return id
  end
  local org_id = require('orgmode.org.id').new()
  self:set_property('ID', org_id):wait()
  return org_id
end

--- A handle copies a headline's data (text, line number, properties) when it is built: on load
--- and when a mutation refreshes it. It cannot keep the internal headline, because every edit
--- reparses the file and replaces it. Before each action, it looks for its headline again:
--- 1. By ID, which does not depend on position or text. A missing or duplicated ID means the
---    headline was removed or copied, so no other match is trusted.
--- 2. By line number, if the file is unchanged since the handle was built. This is exact even
---    among headlines with the same text.
--- 3. By outline path and text, once the file has changed and the line number may point
---    elsewhere. The outline path tells apart headlines with the same text under different
---    parents. Headlines with the same text under the same parents cannot be told apart, so
---    this only counts if it is unique now and was unique when the handle was built.
--- If none of these finds exactly one headline, it returns nil: a guess would change another one.
---@param file OrgFile
---@return OrgHeadline | nil
---@private
function OrgHeadline:_find_section_or_nil(file)
  local id = self.properties.id
  if id then
    local by_id = file:find_headlines_by_id(id)
    if #by_id == 1 then
      return by_id[1]
    end
    return nil
  end

  if file.version == self._file_version then
    return file:get_closest_headline({ self.position.start_line, 0 })
  end

  local same_outline_key = file:find_headlines_by_outline_key(self._outline_key)
  if self._outline_key_unique and #same_outline_key == 1 then
    return same_outline_key[1]
  end
  return nil
end

--- Like _find_section_or_nil, but raises an error when the headline is not found
---@param file OrgFile
---@return OrgHeadline
---@private
function OrgHeadline:_find_section(file)
  local section = self:_find_section_or_nil(file)
  if not section then
    error(string.format('Headline "%s" not found in %s', self.line, self.file.filename), 0)
  end
  return section
end

---@param target table
---@param source table
local function replace_fields(target, source)
  for key in pairs(target) do
    target[key] = nil
  end
  for key, value in pairs(source) do
    target[key] = value
  end
end

--- Refresh the file and headline handles of one load in place, matching headlines by index.
--- A mutation changes the file version, so without a refresh the other handles of the load could
--- no longer use their line number. A mutation changes only its own headline, so while the
--- headline count is unchanged, each index still names the same headline. That only holds if
--- every handle was valid before the mutation.
---@param old_file OrgApiFile
---@param new_file OrgApiFile
local function refresh_handles(old_file, new_file)
  local old_headlines = old_file.headlines
  local old_by_new = {}
  for i, headline in ipairs(new_file.headlines) do
    old_by_new[headline] = old_headlines[i]
  end

  replace_fields(old_file, new_file)
  old_file.headlines = old_headlines
  for i, headline in ipairs(new_file.headlines) do
    local old = old_headlines[i]
    replace_fields(old, headline)
    old.file = old_file
    old.parent = headline.parent and old_by_new[headline.parent]
    old.headlines = vim.tbl_map(function(child)
      return old_by_new[child]
    end, headline.headlines)
  end
end

--- Refresh one handle from its reloaded headline and put it into the reloaded file in place of
--- that headline. Otherwise the next refresh of the file would reach the reloaded copy, not the handle.
---@param handle OrgApiHeadline
---@param updated OrgApiHeadline
local function replace_handle(handle, updated)
  replace_fields(handle, updated)
  for i, headline in ipairs(handle.file.headlines) do
    if headline == updated then
      handle.file.headlines[i] = handle
    end
    if headline.parent == updated then
      headline.parent = handle
    end
  end
  if handle.parent then
    for i, child in ipairs(handle.parent.headlines) do
      if child == updated then
        handle.parent.headlines[i] = handle
      end
    end
  end
end

--- Whether every headline other than the acting one still has its outline key and ID at its old position
---@param handle OrgApiHeadline
---@param updated OrgApiHeadline
---@param new_file OrgApiFile
---@return boolean
local function kept_order(handle, updated, new_file)
  local old_headlines = handle.file.headlines
  if #old_headlines ~= #new_file.headlines then
    return false
  end
  for i, old in ipairs(old_headlines) do
    local new = new_file.headlines[i]
    if old == handle then
      if new ~= updated then
        return false
      end
    elseif old._outline_key ~= new._outline_key or old.properties.id ~= new.properties.id then
      return false
    end
  end
  return true
end

---@class OrgApiHeadlineMark
---@field bufnr number
---@field id number
---@field autocmd number
---@field row? number line of the headline after the save, nil while not saved or when the line is gone

--- Mark the headline line so a write hook (BufWritePre) that moves it is followed, like an Emacs marker.
--- The mark starts at column 1 with left gravity, so text inserted at the start of the line, including a
--- line break, does not take it along. It covers the rest of the line and is deleted once that whole range
--- is deleted, which tells a deleted or replaced line apart from one edited inside.
---@param bufnr number
---@param start_line number
---@return OrgApiHeadlineMark
local function mark_headline_line(bufnr, start_line)
  local row = start_line - 1
  local line = vim.api.nvim_buf_get_lines(bufnr, row, start_line, false)[1]
  local mark = {
    bufnr = bufnr,
    id = vim.api.nvim_buf_set_extmark(bufnr, mark_namespace, row, 1, {
      end_row = row,
      end_col = #line,
      right_gravity = false,
      end_right_gravity = true,
      invalidate = true,
      undo_restore = false,
    }),
  }
  -- Created last, so it reads the mark after the BufWritePost autocmds of the user ran. Closing the
  -- buffer of a file that was not loaded deletes its marks, so the row cannot be read later.
  mark.autocmd = vim.api.nvim_create_autocmd('BufWritePost', {
    buffer = bufnr,
    once = true,
    callback = function()
      local pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, mark_namespace, mark.id, {})
      mark.row = pos[1] and pos[1] + 1
    end,
  })
  return mark
end

---@param mark? OrgApiHeadlineMark
local function unmark_headline_line(mark)
  if not mark then
    return
  end
  -- The autocmd is gone once it ran, and the mark once its buffer was unloaded
  pcall(vim.api.nvim_del_autocmd, mark.autocmd)
  pcall(vim.api.nvim_buf_del_extmark, mark.bufnr, mark_namespace, mark.id)
end

---@param action function
---@param new_id? string|false ID the action leaves the headline with, false for none, to find it by after the change
---@private
function OrgHeadline:_do_action(action, new_id)
  local file = org.files:get(self.file.filename)
  local start_line
  local lines_after_action = {}
  ---@type OrgApiHeadlineMark|nil
  local mark = nil
  local id = self.properties.id
  if new_id ~= nil then
    id = new_id or nil
  end
  local all_handles_valid = true
  return org.files
    :update_file(self.file.filename, function()
      -- A file without a buffer is opened only now, and its read autocmds can change the text
      file:reload_sync()
      local ok, section = pcall(self._find_section, self, file)
      if not ok then
        return Promise.reject(section)
      end
      start_line = section:get_range().start_line
      for _, headline in ipairs(self.file.headlines) do
        if headline._file_version ~= file.version then
          all_handles_valid = false
        end
      end
      local view = vim.fn.winsaveview() or {}
      local bufnr = vim.api.nvim_get_current_buf()
      vim.fn.cursor({ start_line, 1 })
      return Promise.resolve(action()):next(function()
        -- Another buffer can be current by now, for example the closing datepicker
        lines_after_action = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        vim.fn.winrestview(view)
        mark = mark_headline_line(bufnr, start_line)
      end)
    end)
    :next(function()
      local new_file = self.file:reload()
      local updated = nil
      ---@diagnostic disable-next-line: invisible
      if vim.deep_equal(lines_after_action, new_file._file.lines) then
        updated = new_file:get_headline_on_line(start_line)
      elseif id then
        ---@diagnostic disable-next-line: invisible
        local by_id = new_file._file:find_headlines_by_id(id)
        updated = #by_id == 1 and new_file:get_headline_on_line(by_id[1]:get_range().start_line) or nil
      else
        -- A write hook changed the text while the change was saved and can have moved the headline
        local row = mark and mark.row
        updated = row and new_file:get_headline_on_line(row)
      end
      if not updated then
        error(string.format('Headline "%s" is no longer on line %d', self.line, start_line), 0)
      end
      -- A write hook can also reorder headlines while the change is saved. The headline count then stays
      -- the same, but refreshing the other handles by index would bind them to other headlines.
      if all_handles_valid and kept_order(self, updated, new_file) then
        refresh_handles(self.file, new_file)
      else
        replace_handle(self, updated)
      end
      return self
    end)
    :finally(function()
      unmark_headline_line(mark)
    end)
end

--- Get a link destination as string
---
--- Depending if org_id_link_to_org_use_id is set the format is
---
--- id:<uuid>::*title and the id is created if not existing
--- or
--- file:<filepath>::*title
---
--- The result is meant to be used as link_location for OrgApi.insert_link.
--- @return string
function OrgHeadline:get_link()
  -- Creating the ID through the handle refreshes it, so it still finds its headline afterwards
  if config.org_id_link_to_org_use_id then
    self:id_get_or_create()
  end
  local section = self:_find_section(org.files:get(self.file.filename))
  return org.links:get_link_to_headline(section)
end

return OrgHeadline

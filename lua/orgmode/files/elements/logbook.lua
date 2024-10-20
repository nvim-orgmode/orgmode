local Range = require('orgmode.files.elements.range')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local Date = require('orgmode.objects.date')
local Duration = require('orgmode.objects.duration')

---@class OrgLogbook
---@field range OrgRange
---@field items table[]
local Logbook = {}

function Logbook:new(opts)
  opts = opts or {}
  local data = {}
  data.range = opts.range
  data.items = opts.items or {}
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param node TSNode
---@param file OrgFile
---@param dates OrgDate[]
---@return OrgLogbook
function Logbook.from_node(node, file, dates)
  return Logbook.parse(file:get_node_text_list(node), node, dates)
end

---@param lines string[]
---@param dates OrgDate[]
function Logbook:add(lines, node, dates)
  local items = Logbook._parse_clocks(lines, node, dates)
  if #items > 0 then
    self.items = utils.concat(self.items, items)
  end
end

---@return boolean
function Logbook:is_active()
  return self:get_active() ~= nil
end

---@return table
function Logbook:get_active()
  return vim.tbl_filter(function(item)
    return not item.end_time
  end, self.items)[1]
end

---@param from? OrgDate
---@param to? OrgDate
---@return number
function Logbook:get_total_minutes(from, to)
  local total_minutes = 0
  local has_range = from and to
  for _, item in ipairs(self.items) do
    if item.duration then
      if not has_range or (item.start_time:is_between(from, to) or item.end_time:is_between(from, to)) then
        total_minutes = total_minutes + item.duration.minutes
      end
    end
  end
  return total_minutes
end

---@param from? OrgDate
---@param to? OrgDate
---@return OrgDuration
function Logbook:get_total(from, to)
  return Duration.from_minutes(self:get_total_minutes(from, to))
end

function Logbook:get_total_with_active()
  local duration = self:get_total()
  local active = self:get_active()
  if not active then
    return duration
  end
  local active_duration = Duration.from_seconds(Date.now().timestamp - active.start_time.timestamp)
  return Duration.from_minutes(duration.minutes + active_duration.minutes)
end

function Logbook:add_clock_in()
  local indent = vim.fn.getline(self.range.start_line):match('^%s*')
  local line = self.range.start_line
  local date = Date.now({ active = false })
  local content = string.format('%sCLOCK: %s', indent, date:to_wrapped_string())
  table.insert(self.items, {
    start_time = date,
    end_time = nil,
  })
  vim.api.nvim_call_function('append', { line, content })
  utils.echo_info(string.format('Clock starts at %s', date:to_wrapped_string()))
end

function Logbook:clock_out()
  local active_item = self:get_active()
  if not active_item then
    return
  end
  local line_nr = active_item.start_time.range.start_line
  local line = vim.fn.getline(line_nr)
  local date = Date.now({ active = false })
  active_item.end_time = date
  active_item.duration = Duration.from_seconds(date.timestamp - active_item.start_time.timestamp)
  local minutes = active_item.duration:to_string('HH:MM')
  line = string.format('%s--%s => %s', line, date:to_wrapped_string(), minutes)
  utils.echo_info(string.format('Clock stopped at %s after %s', date:to_wrapped_string(), minutes))
  vim.api.nvim_call_function('setline', { line_nr, line })
end

function Logbook:cancel_active_clock()
  local active_item = nil
  local index = 0
  for i, item in ipairs(self.items) do
    if not item.end_time then
      active_item = item
      index = i
      break
    end
  end
  if not active_item then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  -- Delete whole drawer if there are no any other entries
  if #self.items == 1 then
    return vim.fn.deletebufline(buf, self.range.start_line, self.range.end_line)
  end
  vim.fn.deletebufline(buf, self.range.start_line + index)
end

function Logbook:recalculate_estimate(line)
  local item = self.items[line - self.range.start_line]
  if not item or not item.end_time then
    return
  end
  local content = vim.fn.getline(line):gsub('%s*=>%s*[%-%+]?%d+:%d+%s*$', '')
  content = string.format('%s => %s', content, item.duration:to_string('HH:MM'))
  local view = vim.fn.winsaveview() or {}
  vim.api.nvim_call_function('setline', { line, content })
  vim.fn.winrestview(view)
end

---@param lines string[]
---@param node TSNode
---@param dates OrgDate[]
---@return OrgLogbook
function Logbook.parse(lines, node, dates)
  local opts = {
    range = Range.from_node(node),
    items = Logbook._parse_clocks(lines, node, dates),
  }

  return Logbook:new(opts)
end

---@param headline OrgHeadline
function Logbook.new_from_headline(headline)
  local append_line = headline:get_append_line()
  local indent = headline:get_indent()

  local date = Date.now({ active = false })
  local content = {
    string.format('%s:LOGBOOK:', indent),
    string.format('%s:END:', indent),
  }
  vim.api.nvim_call_function('append', { append_line, content })

  return Logbook:new({
    range = Range:new({ start_line = append_line + 1, end_line = append_line + 3 }),
    items = { {
      start_time = date,
      end_time = nil,
    } },
  })
end

---@param lines string[]
---@param node any
---@param dates OrgDate[]
---@return table
function Logbook._parse_clocks(lines, node, dates)
  local items = {}
  local range = Range.from_node(node)
  for i, drawer_prop in ipairs({ unpack(lines, 2, #lines - 1) }) do
    local prop_name, _ = drawer_prop:match('^%s*:?([^:]-):%s*(.*)$')
    if prop_name and prop_name:upper() == 'CLOCK' then
      local dates_for_line = {}
      for _, clock_date in ipairs(dates) do
        if clock_date.range.start_line == range.start_line + i then
          clock_date.type = 'LOGBOOK'
          table.insert(dates_for_line, clock_date)
        end
      end
      if #dates_for_line > 0 then
        local item = {
          start_time = dates_for_line[1],
          end_time = dates_for_line[2],
        }
        if item.start_time and item.end_time then
          item.duration = Duration.from_seconds(item.end_time.timestamp - item.start_time.timestamp)
        end
        table.insert(items, item)
      end
    end
  end
  return items
end

return Logbook

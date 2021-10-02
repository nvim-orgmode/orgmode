local Range = require('orgmode.parser.range')
local utils = require('orgmode.utils')
local config = require('orgmode.config')
local Date = require('orgmode.objects.date')
local Duration = require('orgmode.objects.duration')

---@class Logbook
---@field range Range
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

---@param lines string[]
---@param dates Date[]
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

function Logbook:add_clock_in()
  local indent = vim.fn.getline(self.range.start_line):match('^%s*')
  local line = self.range.end_line - 1
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
  local minutes = self:_calculate_minutes(active_item.start_time, active_item.end_time)
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
  vim.fn.deletebufline(vim.api.nvim_get_current_buf(), self.range.start_line + index)
end

function Logbook:recalculate_estimate(line)
  local item = self.items[line - self.range.start_line]
  if not item or not item.end_time then
    return
  end
  local content = vim.fn.getline(line):gsub('%s*=>%s*[%-%+]?%d+:%d+%s*$', '')
  content = string.format('%s => %s', content, self:_calculate_minutes(item.start_time, item.end_time))
  local view = vim.fn.winsaveview()
  vim.api.nvim_call_function('setline', { line, content })
  vim.fn.winrestview(view)
end

---@param start_time Date
---@param end_time Date
---@return string
function Logbook:_calculate_minutes(start_time, end_time)
  local seconds = end_time.timestamp - start_time.timestamp
  local duration = Duration.from_seconds(seconds)
  return duration:to_string('HH:MM')
end

---@param lines string
---@param dates string
---@return Logbook
function Logbook.parse(lines, node, dates)
  local opts = {
    range = Range.from_node(node),
    items = Logbook._parse_clocks(lines, node, dates),
  }

  return Logbook:new(opts)
end

---@param section Section
---@return Logbook
function Logbook.new_from_section(section)
  local line = nil
  if section.properties.valid then
    line = section.properties.range.end_line + 1
  else
    line = section:has_planning() and section.range.start_line + 1 or section.range.start_line
  end
  local indent = ''
  if config.org_indent_mode == 'indent' then
    indent = string.rep(' ', section.level + 1)
  end

  local date = Date.now({ active = false })
  local content = {
    string.format('%s:LOGBOOK:', indent),
    string.format('%sCLOCK: %s', indent, date:to_wrapped_string()),
    string.format('%s:END:', indent),
  }
  vim.api.nvim_call_function('append', { line, content })

  return Logbook:new({
    range = Range:new({ start_line = line + 1, end_line = line + 3 }),
    items = { {
      start_time = date,
      end_time = nil,
    } },
  })
end

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
        table.insert(items, {
          start_time = dates_for_line[1],
          end_time = dates_for_line[2],
        })
      end
    end
  end
  return items
end

return Logbook

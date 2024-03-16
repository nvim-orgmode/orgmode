local Url = require('orgmode.org.hyperlinks.url')
local Range = require('orgmode.files.elements.range')

---@class OrgLink
---@field url OrgUrl
---@field desc string | nil
---@field range? OrgRange
local Link = {}

local pattern = '%[%[([^%]]+.-)%]%]'

---@param str string
---@param range? OrgRange
---@return OrgLink
function Link:new(str, range)
  local this = setmetatable({}, { __index = Link })
  local parts = vim.split(str, '][', { plain = true })
  this.url = Url:new(parts[1] or '')
  this.desc = parts[2]
  this.range = range
  return this
end

---@return string
function Link:to_str()
  if self.desc then
    return string.format('[[%s][%s]]', self.url:to_string(), self.desc)
  else
    return string.format('[[%s]]', self.url:to_string())
  end
end

---@param line string
---@param pos number
---@return OrgLink | nil, table | nil
function Link.at_pos(line, pos)
  local links = {}
  local found_link = nil
  local position
  for link in line:gmatch(pattern) do
    local start_from = #links > 0 and links[#links].to or nil
    local from, to = line:find(pattern, start_from)
    local current_pos = { from = from, to = to }
    if pos >= from and pos <= to then
      found_link = link
      position = current_pos
      break
    end
    table.insert(links, current_pos)
  end
  if not found_link then
    return nil, nil
  end
  return Link:new(found_link), position
end

function Link.all_from_line(line, line_number)
  local links = {}
  for link in line:gmatch(pattern) do
    local start_from = #links > 0 and links[#links].to or nil
    local from, to = line:find(pattern, start_from)
    if from and to then
      local range = Range.from_line(line_number)
      range.start_col = from
      range.end_col = to
      table.insert(links, Link:new(link, range))
    end
  end

  return links
end

return Link

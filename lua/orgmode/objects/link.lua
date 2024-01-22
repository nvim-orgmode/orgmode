local Url = require('orgmode.objects.url')
local utils = require('orgmode.utils')

---@class OrgLink
---@field url OrgUrl
---@field desc string | nil
local Link = {}

---@param str string
function Link:init(str)
  local parts = vim.split(str, '][', { plain = true })
  self.url = Url.new(parts[1] or '')
  self.desc = parts[2]
  return self
end

---@return string
function Link:to_str()
  if self.desc then
    return string.format('[[%s][%s]]', self.url.str, self.desc)
  else
    return string.format('[[%s]]', self.url.str)
  end
end

---@param str string
---@return OrgLink
function Link.new(str)
  local self = setmetatable({}, { __index = Link })
  return self:init(str)
end

---@param line string
---@param pos number
---@return OrgLink | nil, table | nil
function Link.at_pos(line, pos)
  local links = {}
  local found_link = nil
  local pattern = '%[%[([^%]]+.-)%]%]'
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
  return Link.new(found_link), position
end

return Link

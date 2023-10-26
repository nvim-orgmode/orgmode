local Url = require('orgmode.objects.url')

---@class Link
---@field url Url
---@field desc string | nil
local Link = {}

---@param str string
function Link:init(str)
  local parts = vim.split(str, '][', true)
  self.url = Url.new(parts[1] or '')
  self.desc = parts[2]
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
function Link.new(str)
  local self = setmetatable({}, { __index = Link })
  self:init(str)
  return self
end

---@param line string
---@param pos number
---@return Link | nil
function Link.at_pos(line, pos)
  local links = {}
  local found_link = nil
  local pattern = '%[%[([^%]]+.-)%]%]'
  for link in line:gmatch(pattern) do
    local start_from = #links > 0 and links[#links].to or nil
    local from, to = line:find(pattern, start_from)
    if pos >= from and pos <= to then
      found_link = link
      break
    end
    table.insert(links, { link = link, from = from, to = to })
  end
  return (found_link and Link.new(found_link) or nil)
end

return Link

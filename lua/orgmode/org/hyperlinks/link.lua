local Url = require('orgmode.org.hyperlinks.url')

---@class OrgLink
---@field url OrgUrl
---@field desc string | nil
local Link = {}

---@param str string
---@return OrgLink
function Link:new(str)
  local this = setmetatable({}, { __index = Link })
  local parts = vim.split(str, '][', { plain = true })
  this.url = Url:new(parts[1] or '')
  this.desc = parts[2]
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
  return Link:new(found_link), position
end

return Link

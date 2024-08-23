local OrgLinkUrl = require('orgmode.org.links.url')
local Range = require('orgmode.files.elements.range')

---@class OrgHyperlink
---@field url OrgLinkUrl
---@field desc string | nil
---@field range? OrgRange
local OrgHyperlink = {}

local pattern = '%[%[([^%]]+.-)%]%]'

---@param str string
---@param range? OrgRange
---@return OrgHyperlink
function OrgHyperlink:new(str, range)
  local this = setmetatable({}, { __index = OrgHyperlink })
  local parts = vim.split(str, '][', { plain = true })
  this.url = OrgLinkUrl:new(parts[1] or '')
  this.desc = parts[2]
  this.range = range
  return this
end

---@return string
function OrgHyperlink:to_str()
  if self.desc then
    return string.format('[[%s][%s]]', self.url:to_string(), self.desc)
  else
    return string.format('[[%s]]', self.url:to_string())
  end
end

---@param line string
---@param pos number
---@return OrgHyperlink | nil, { from: number, to: number } | nil
function OrgHyperlink.at_pos(line, pos)
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
  return OrgHyperlink:new(found_link), position
end

---@return OrgHyperlink | nil, { from: number, to: number } | nil
function OrgHyperlink.at_cursor()
  local line = vim.fn.getline('.')
  local col = vim.fn.col('.') or 0
  return OrgHyperlink.at_pos(line, col)
end

---@return OrgHyperlink[]
function OrgHyperlink.all_from_line(line, line_number)
  local links = {}
  for link in line:gmatch(pattern) do
    local start_from = #links > 0 and links[#links].to or nil
    local from, to = line:find(pattern, start_from)
    if from and to then
      local range = Range.from_line(line_number)
      range.start_col = from
      range.end_col = to
      table.insert(links, OrgHyperlink:new(link, range))
    end
  end

  return links
end

return OrgHyperlink

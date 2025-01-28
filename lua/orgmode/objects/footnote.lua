local Range = require('orgmode.files.elements.range')

---@class OrgFootnote
---@field value string
---@field range? OrgRange
local OrgFootnote = {}
OrgFootnote.__index = OrgFootnote

local pattern = '%[fn:[^%]]+%]'

---@param str string
---@param range? OrgRange
---@return OrgFootnote
function OrgFootnote:new(str, range)
  local this = setmetatable({}, { __index = OrgFootnote })
  this.value = str
  this.range = range
  return this
end

function OrgFootnote:get_name()
  local name = self.value:match('^%[fn:([^%]]+)%]$')
  return name
end

---@return OrgFootnote | nil
function OrgFootnote.at_cursor()
  local line_nr = vim.fn.line('.')
  local col = vim.fn.col('.') or 0
  local on_line = OrgFootnote.all_from_line(vim.fn.getline('.'), line_nr)

  return vim.iter(on_line):find(function(footnote)
    return footnote.range:is_in_range(line_nr, col)
  end)
end

---@return OrgFootnote[]
function OrgFootnote.all_from_line(line, line_number)
  local links = {}
  for link in line:gmatch(pattern) do
    local start_from = #links > 0 and links[#links].range.end_col or nil
    local from, to = line:find(pattern, start_from)
    if from and to then
      local range = Range.from_line(line_number)
      range.start_col = from
      range.end_col = to
      table.insert(links, OrgFootnote:new(link, range))
    end
  end

  return links
end

return OrgFootnote

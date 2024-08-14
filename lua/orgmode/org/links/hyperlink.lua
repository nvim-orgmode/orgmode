local Org = require('orgmode')

---@class OrgHyperLink
---@field link OrgLinkHandler
---@field desc? string
---@field range? OrgRange
local HyperLink = {}

---@param self OrgHyperLink
---@param link OrgLinkHandler
---@param desc? string
---@param range? OrgRange
---@return OrgHyperLink
function HyperLink:new(link, desc, range)
  local this = setmetatable({}, self)
  self.__index = self
  this.link = link
  this.desc = desc
  this.range = range

  return this
end

function HyperLink:follow()
  self.link:follow()
end

---@return string
function HyperLink:__tostring()
  if self.desc then
    return string.format('[[%s][%s]]', self.link, self.desc)
  else
    return string.format('[[%s]]', self.link)
  end
end

--- Given a string, tries to parse the start of the string as an Org hyperlink
--- Returns the link, then the description, then the rest of the string
---@param input string @ String with potential link at the start
---@return string?, string?, string?
local function parse_link(input)
  -- Doesn't start with a link
  if input:find('^%[%[') == nil then
    return nil
  end

  local substr = input:sub(3)
  local _, close = substr:find('[^\\]%]')
  local _, open = substr:find('[^\\]%[')

  -- No closing ] -> invalid
  if not close then
    return nil
  end

  -- Unescaped [ before unescaped ] means it's an invalid link
  if open and close > open then
    return nil
  end

  local link = substr:sub(1, close - 1)
  substr = substr:sub(close)

  -- Link without description
  if substr:find('^%]%]') then
    return link, nil, substr:sub(3)
  end

  -- Must have a description at this point, else it's invalid syntax
  if substr:find('^%]%[') == nil then
    return nil
  end

  substr = substr:sub(3)
  local desc_end = substr:find('.%]%]')

  -- Description must have content, and end at some point, else it's invalid syntax
  if desc_end == nil then
    return nil
  end

  return link, substr:sub(1, desc_end), substr:sub(desc_end + 3)
end

---@param line string @ line contents
---@param line_number number? @ line number for range
---@return OrgHyperLink[]
function HyperLink.all_from_line(line, line_number)
  local links = {}
  local str = line
  local pos = 0

  repeat
    local start = str:find('[^\\]%[%[')
    if start == nil then
      break
    end
    str = str:sub(start + 1)
    pos = pos + start + 1

    local link_str, desc, next_str = parse_link(str)
    local link = Org.links:parse(link_str)

    if link then
      local range = Range:new({
        start_line = line_number,
        end_line = line_number,
        start_col = pos,
        end_col = pos + (#str - #next_str),
      })
      links[#links + 1] = HyperLink:new(link, desc, range)
      str = next_str
      pos = range.end_col + 1
    else
      str = str:sub(2)
    end
  until #str == 0

  return links
end

---@param line string @ line contents
---@param pos number
---@return OrgHyperLink | nil
function HyperLink.at_pos(line, pos)
  local links = HyperLink.all_from_line(line)

  for _, link in pairs(links) do
    if link.range.start_col <= pos and link.range.end_col >= pos then
      return link
    end
  end
  return nil
end

---@return OrgHyperLink|nil
function HyperLink.get_link_under_cursor()
  local line = vim.fn.getline('.')
  local col = vim.fn.col('.') or 0
  local link = HyperLink.at_pos(line, col)
  if not link then
    return nil
  end

  local line_number = vim.fn.line('.') or 0
  link.range.start_line = line_number
  link.range.end_line = line_number
  return link
end

function HyperLink:insert_link()
  local link_under_cursor = HyperLink.get_link_under_cursor()
  local cursor_line = vim.fn.getline('.')
  local line_pre
  local line_post

  if link_under_cursor then
    line_pre = cursor_line:sub(0, link_under_cursor.range.start_col)
    line_post = cursor_line:sub(link_under_cursor.range.end_col)
  else
    local cursor_pos = vim.fn.col('.')
    line_pre = cursor_line:sub(0, cursor_pos)
    line_post = cursor_line:sub(cursor_pos + 1)
  end

  self.link = self.link:resolve()
  local link_str = tostring(self)
  local new_line = line_pre .. link_str .. line_post

  local linenr = vim.fn.line('.')
  vim.fn.setline(linenr, new_line)
  vim.fn.cursor(linenr, #line_pre + #link_str + 1)
end

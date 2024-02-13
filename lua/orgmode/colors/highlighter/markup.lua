local config = require('orgmode.config')

---@class OrgMarkupHighlighter
---@field highlighter OrgHighlighter
---@field private cache table
local OrgMarkup = {}

---@param opts { highlighter: OrgHighlighter }
function OrgMarkup:new(opts)
  local data = {
    highlighter = opts.highlighter,
    cache = setmetatable({}, { __mode = 'k' }),
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function OrgMarkup:on_win(bufnr, topline, botline)
  -- TODO
  return true
end

function OrgMarkup:on_line(bufnr, line)
  -- TODO
  return true
end

function OrgMarkup:on_detach(bufnr)
  self.cache[bufnr] = nil
end

return OrgMarkup

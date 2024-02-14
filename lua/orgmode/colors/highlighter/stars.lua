local config = require('orgmode.config')

---@class OrgStarsHighlighter
---@field highlighter OrgHighlighter
local OrgStars = {}

---@param opts { highlighter: OrgHighlighter }
function OrgStars:new(opts)
  local data = {
    highlighter = opts.highlighter,
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

function OrgStars:_is_enabled(bufnr)
  if config.org_hide_leading_stars then
    return true
  end

  if vim.b[bufnr].org_indent_mode and config.org_indent_mode_turns_on_hiding_stars then
    return true
  end

  return false
end

function OrgStars:on_line(bufnr, line)
  if not self:_is_enabled(bufnr) then
    return
  end

  local node = vim.treesitter.get_node({
    bufnr = bufnr,
    pos = { line, 0 },
  })

  if not node or node:type() ~= 'stars' then
    return
  end

  local _, end_col = node:end_()

  vim.api.nvim_buf_set_extmark(bufnr, self.highlighter.namespace, line, 0, {
    end_line = line,
    end_col = end_col - 1,
    hl_group = 'OrgHideLeadingStars',
    ephemeral = true,
  })
end

return OrgStars

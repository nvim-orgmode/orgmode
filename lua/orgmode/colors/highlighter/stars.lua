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

function OrgStars:on_line(bufnr, line)
  if not config:hide_leading_stars(bufnr) then
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
    hl_group = '@org.leading_stars',
    ephemeral = true,
  })
end

return OrgStars

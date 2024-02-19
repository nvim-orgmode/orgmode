local config = require('orgmode.config')
local utils = require('orgmode.utils')

---@alias OrgFoldtextLineValue false | { col: number, hl_group: string }

---@class OrgFoldtextHighlighter
---@field highlighter OrgHighlighter
---@field namespace number
---@field enabled number
---@field cache table<number, table<number, OrgFoldtextLineValue>>
local OrgFoldtext = {}

---@param opts { highlighter: OrgHighlighter }
function OrgFoldtext:new(opts)
  local data = {
    highlighter = opts.highlighter,
    enabled = utils.has_version_10(),
    cache = setmetatable({}, { __mode = 'k' }),
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param bufnr number
---@param line number
---@param value OrgFoldtextLineValue
function OrgFoldtext:_highlight(bufnr, line, value)
  if not value then
    return
  end

  vim.api.nvim_buf_set_extmark(bufnr, self.highlighter.namespace, line, value.col, {
    hl_mode = 'combine',
    virt_text = { { config.org_ellipsis, value.hl_group } },
    virt_text_pos = 'overlay',
    ephemeral = true,
  })
end

function OrgFoldtext:on_line(bufnr, line)
  if not self.enabled then
    return false
  end

  local is_current_buf = bufnr == vim.api.nvim_get_current_buf()

  if not is_current_buf then
    return self:_highlight(bufnr, line, self.cache[bufnr] and self.cache[bufnr][line])
  end

  self.cache[bufnr] = self.cache[bufnr] or {}
  local is_fold_closed = vim.fn.foldclosed(line + 1) > -1

  if not is_fold_closed then
    self.cache[bufnr][line] = false
    return
  end

  local col = vim.fn.col({ line + 1, '$' }) or 0

  local hl_group = 'Comment'
  local captures_at_pos = vim.treesitter.get_captures_at_pos(bufnr, line, col - 2)

  if #captures_at_pos > 0 then
    for i = #captures_at_pos, 1, -1 do
      local capture = captures_at_pos[i]
      if capture.capture ~= 'spell' then
        hl_group = table.concat({ '@', capture.capture, '.', capture.lang }, '')
        break
      end
    end
  end

  self.cache[bufnr][line] = { col = col - 1, hl_group = hl_group }
  return self:_highlight(bufnr, line, self.cache[bufnr][line])
end

function OrgFoldtext:on_detach(bufnr)
  self.cache[bufnr] = nil
end

return OrgFoldtext

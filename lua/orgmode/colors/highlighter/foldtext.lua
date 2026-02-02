local config = require('orgmode.config')

---@alias OrgFoldtextLineValue false | { col: number, hl_group: string }

---@class OrgFoldtextHighlighter
---@field highlighter OrgHighlighter
---@field namespace number
---@field cache table<number, table<number, OrgFoldtextLineValue>>
local OrgFoldtext = {}

---@param opts { highlighter: OrgHighlighter }
function OrgFoldtext:new(opts)
  local data = {
    highlighter = opts.highlighter,
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
    ephemeral = self.highlighter._ephemeral,
  })
end

function OrgFoldtext:on_line(bufnr, line, winid)
  if not config.ui.folds.colored then
    return
  end

  -- Use provided winid for correct window context (foldclosed and col are window-local)
  local lnum = line + 1
  local is_fold_open, line_end

  if winid and winid ~= vim.api.nvim_get_current_win() then
    -- foldclosed() and col() are window-local, so execute in the correct window
    vim.api.nvim_win_call(winid, function()
      is_fold_open = vim.fn.foldclosed(lnum) == -1
      line_end = vim.fn.col({ lnum, '$' }) or 0
    end)
  else
    is_fold_open = vim.fn.foldclosed(lnum) == -1
    line_end = vim.fn.col({ lnum, '$' }) or 0
  end

  local cache_entry = self.cache[bufnr] and self.cache[bufnr][line]

  -- Cache: nil = unprocessed, false = open, {col, hl_group} = closed
  if cache_entry ~= nil then
    local was_open = cache_entry == false
    if was_open == is_fold_open then
      if cache_entry and cache_entry.col then
        if cache_entry.col == line_end - 1 then
          return self:_highlight(bufnr, line, cache_entry)
        end
        -- Line length changed, need full update
      else
        return self:_highlight(bufnr, line, cache_entry)
      end
    end
  end

  -- Full update: query treesitter
  self.cache[bufnr] = self.cache[bufnr] or {}

  if is_fold_open then
    self.cache[bufnr][line] = false
    return -- No ellipsis to highlight
  end

  local col = line_end

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

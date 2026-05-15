local config = require('orgmode.config')

---@alias OrgFoldtextLineValue { col: number, hl_group: string }

---@class OrgFoldtextWinState
---@field topline number 0-based, first line of the visible range
---@field line_ends table<number, number> 0-based line → byte length of line content
---@field is_closed table<number, true> 0-based line → true if this line is the start of a closed fold

---@class OrgFoldtextHighlighter
---@field highlighter OrgHighlighter
---@field namespace number
---@field cache table<number, table<number, OrgFoldtextLineValue>>
---@field win_state table<number, OrgFoldtextWinState>
---@field attached table<number, boolean>
local OrgFoldtext = {}

---@param opts { highlighter: OrgHighlighter }
function OrgFoldtext:new(opts)
  local data = {
    highlighter = opts.highlighter,
    cache = setmetatable({}, { __mode = 'k' }),
    win_state = {},
    attached = {},
  }
  setmetatable(data, self)
  self.__index = self
  return data
end

---Apply an `on_bytes` change to the cache: drop entries inside the changed
---range and shift entries after it by the row delta. Replaces the previous
---wholesale `changedtick`-based invalidation, so unaffected lines retain
---their cached hl_group across edits.
---@param bufnr number
---@param start_row number 0-based
---@param old_end_row number rows in old range (relative to start_row)
---@param new_end_row number rows in new range (relative to start_row)
function OrgFoldtext:_apply_change(bufnr, start_row, old_end_row, new_end_row)
  local cache = self.cache[bufnr]
  if not cache then
    return
  end

  if old_end_row == new_end_row then
    for line = start_row, start_row + old_end_row do
      cache[line] = nil
    end
    return
  end

  local delta = new_end_row - old_end_row
  local boundary = start_row + old_end_row
  local shifted = {}
  for k, v in pairs(cache) do
    if k < start_row then
      shifted[k] = v
    elseif k > boundary then
      shifted[k + delta] = v
    end
  end
  self.cache[bufnr] = shifted
end

---Attach a buffer listener that keeps the hl_group cache consistent with
---buffer edits. Idempotent — only attaches once per buffer.
---@param bufnr number
function OrgFoldtext:_attach(bufnr)
  if self.attached[bufnr] then
    return
  end
  local ok = vim.api.nvim_buf_attach(bufnr, false, {
    on_bytes = function(_, b, _tick, start_row, _, _, old_end_row, _, _, new_end_row)
      self:_apply_change(b, start_row, old_end_row, new_end_row)
    end,
    on_reload = function(_, b)
      self.cache[b] = nil
    end,
    on_detach = function(_, b)
      self:on_detach(b)
    end,
  })
  if ok then
    self.attached[bufnr] = true
  end
end

---Build per-window fold-state map for the visible range, replacing per-line
---`vim.fn.foldclosed` and `vim.fn.col` calls in `on_line` with O(1) lookups.
---@param bufnr number
---@param winid number
---@param topline number 0-based
---@param botline number 0-based, inclusive
function OrgFoldtext:on_win(bufnr, winid, topline, botline)
  if not config.ui.folds.colored then
    self.win_state[winid] = nil
    return
  end

  self:_attach(bufnr)

  local lines = vim.api.nvim_buf_get_lines(bufnr, topline, botline + 1, false)
  local line_ends = {}
  for i, content in ipairs(lines) do
    line_ends[topline + i - 1] = #content
  end

  local is_closed = {}
  local scan = function()
    local lnum = topline + 1
    local last = botline + 1
    while lnum <= last do
      local fc = vim.fn.foldclosed(lnum)
      if fc == -1 then
        lnum = lnum + 1
      else
        is_closed[fc - 1] = true
        local fend = vim.fn.foldclosedend(lnum)
        lnum = (fend or lnum) + 1
      end
    end
  end

  if winid == vim.api.nvim_get_current_win() then
    scan()
  else
    vim.api.nvim_win_call(winid, scan)
  end

  self.win_state[winid] = {
    topline = topline,
    line_ends = line_ends,
    is_closed = is_closed,
  }
end

---@param bufnr number
---@param line number
---@param value OrgFoldtextLineValue
function OrgFoldtext:_highlight(bufnr, line, value)
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

  local state = self.win_state[winid]
  if not state or not state.is_closed[line] then
    return
  end

  local line_end = state.line_ends[line]
  if not line_end or line_end <= 0 then
    return
  end

  local col = line_end
  local cache_entry = self.cache[bufnr] and self.cache[bufnr][line]
  if cache_entry and cache_entry.col == col then
    return self:_highlight(bufnr, line, cache_entry)
  end

  local hl_group = 'Comment'
  local captures_at_pos = vim.treesitter.get_captures_at_pos(bufnr, line, col - 1)

  if #captures_at_pos > 0 then
    for i = #captures_at_pos, 1, -1 do
      local capture = captures_at_pos[i]
      if capture.capture ~= 'spell' then
        hl_group = table.concat({ '@', capture.capture, '.', capture.lang }, '')
        break
      end
    end
  end

  self.cache[bufnr] = self.cache[bufnr] or {}
  self.cache[bufnr][line] = { col = col, hl_group = hl_group }
  return self:_highlight(bufnr, line, self.cache[bufnr][line])
end

function OrgFoldtext:on_detach(bufnr)
  self.cache[bufnr] = nil
  self.attached[bufnr] = nil
end

return OrgFoldtext

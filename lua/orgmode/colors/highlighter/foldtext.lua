local config = require('orgmode.config')

---@alias OrgFoldtextLineValue { col: number, hl_group: string, line_content: string }

---@class OrgFoldtextWinState
---@field topline number 0-based, first line of the visible range
---@field lines table<number, string> 0-based line → line content
---@field is_closed table<number, true> 0-based line → true if this line is the start of a closed fold

---@class OrgFoldtextHighlighter
---@field highlighter OrgHighlighter
---@field namespace number
---@field cache table<number, table<number, OrgFoldtextLineValue>>
---@field win_state table<number, OrgFoldtextWinState>
local OrgFoldtext = {}

---@param opts { highlighter: OrgHighlighter }
function OrgFoldtext:new(opts)
  local data = {
    highlighter = opts.highlighter,
    cache = setmetatable({}, { __mode = 'k' }),
    win_state = {},
  }
  setmetatable(data, self)
  self.__index = self
  return data
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

  local lines = {}
  for i, content in ipairs(vim.api.nvim_buf_get_lines(bufnr, topline, botline + 1, false)) do
    lines[topline + i - 1] = content
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
    lines = lines,
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

  local line_content = state.lines[line]
  if not line_content or #line_content == 0 then
    return
  end

  local col = #line_content
  local cache_entry = self.cache[bufnr] and self.cache[bufnr][line]
  if cache_entry and cache_entry.line_content == line_content then
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
  self.cache[bufnr][line] = { col = col, hl_group = hl_group, line_content = line_content }
  return self:_highlight(bufnr, line, self.cache[bufnr][line])
end

function OrgFoldtext:on_detach(bufnr)
  self.cache[bufnr] = nil
end

return OrgFoldtext

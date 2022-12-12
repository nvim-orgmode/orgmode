local config = require('orgmode.config')
local namespace = vim.api.nvim_create_namespace('org_custom_highlighter')
local HideLeadingStars = nil
local MarkupHighlighter = nil
local valid_bufnrs = {}

---@param bufnr number
---@param first_line number
---@param last_line number
local function apply_highlights(bufnr, first_line, last_line, tick_changed)
  local changed_lines = vim.api.nvim_buf_get_lines(bufnr, first_line, last_line, false)
  HideLeadingStars.apply(namespace, bufnr, changed_lines, first_line, last_line)
  MarkupHighlighter.apply(namespace, bufnr, changed_lines, first_line, last_line, tick_changed)
end

local function setup()
  local ts_highlights_enabled = config:ts_highlights_enabled()
  if not ts_highlights_enabled then
    return
  end
  require('orgmode.colors.todo_highlighter').add_todo_keyword_highlights()
  HideLeadingStars = require('orgmode.colors.hide_leading_stars')
  MarkupHighlighter = require('orgmode.colors.markup_highlighter')

  MarkupHighlighter.setup()

  vim.api.nvim_set_decoration_provider(namespace, {
    on_win = function(_, _, bufnr, topline, botline)
      local changedtick = vim.api.nvim_buf_get_var(bufnr, 'changedtick')
      local tick_changed = not valid_bufnrs[bufnr] or valid_bufnrs[bufnr] ~= changedtick
      if valid_bufnrs[bufnr] then
        valid_bufnrs[bufnr] = changedtick
        return apply_highlights(bufnr, topline, botline, tick_changed)
      end
      local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
      if ft == 'org' then
        valid_bufnrs[bufnr] = changedtick
        return apply_highlights(bufnr, topline, botline, tick_changed)
      end
    end,
  })
end

return {
  setup = setup,
}

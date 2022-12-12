local config = require('orgmode.config')
local namespace = vim.api.nvim_create_namespace('org_custom_highlighter')
local HideLeadingStars = nil
local MarkupHighlighter = nil
local valid_bufnrs = {}

---@param bufnr number
local function apply_highlights(bufnr, line)
  HideLeadingStars.apply(namespace, bufnr, line)
  MarkupHighlighter.apply(namespace, bufnr, line)
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
    on_start = function(_, tick)
      local bufnr = vim.api.nvim_get_current_buf()
      if valid_bufnrs[bufnr] == tick or vim.bo[bufnr].filetype ~= 'org' then
        return false
      end
      valid_bufnrs[bufnr] = tick
      return true
    end,
    on_win = function(_, _, bufnr)
      return valid_bufnrs[bufnr] ~= nil and vim.bo[bufnr].filetype == 'org'
    end,
    on_line = function(_, _, bufnr, line)
      return apply_highlights(bufnr, line)
    end,
  })
end

return {
  setup = setup,
}

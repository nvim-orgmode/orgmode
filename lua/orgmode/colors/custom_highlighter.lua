local config = require('orgmode.config')
local namespace = vim.api.nvim_create_namespace('org_custom_highlighter')
local HideLeadingStars = nil
local MarkupHighlighter = nil

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

  require('orgmode.colors.from_config').setup()

  HideLeadingStars = require('orgmode.colors.hide_leading_stars')
  MarkupHighlighter = require('orgmode.colors.markup_highlighter')

  MarkupHighlighter.setup()

  vim.api.nvim_set_decoration_provider(namespace, {
    on_win = function(_, _, bufnr)
      return vim.bo[bufnr].filetype == 'org'
    end,
    on_line = function(_, _, bufnr, line)
      return apply_highlights(bufnr, line)
    end,
  })
end

return {
  setup = setup,
}

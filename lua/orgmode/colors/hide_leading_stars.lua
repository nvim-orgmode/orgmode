local config = require('orgmode.config')
local namespace = vim.api.nvim_create_namespace('org_hide_leading_stars')
local valid_bufnrs = {}

local function update_line_highlight(bufnr, line_index, line)
  local stars = line:match('^%*+')
  if stars then
    vim.api.nvim_buf_set_extmark(bufnr, namespace, line_index, 0, {
      end_line = line_index,
      end_col = stars:len() - 1,
      hl_group = 'OrgHideLeadingStars',
      ephemeral = true,
    })
  end
end

local function update_range_highlight(bufnr, first_line, last_line)
  local changed_lines = vim.api.nvim_buf_get_lines(bufnr, first_line, last_line, false)
  for i, line in ipairs(changed_lines) do
    update_line_highlight(bufnr, first_line + i - 1, line)
  end
end

local function setup_hide_leading_stars()
  if not config.org_hide_leading_stars then
    return
  end
  vim.api.nvim_set_decoration_provider(namespace, {
    on_win = function(_, _, bufnr, topline, botline)
      if valid_bufnrs[bufnr] then
        return update_range_highlight(bufnr, topline, botline)
      end
      local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
      if ft == 'org' then
        valid_bufnrs[bufnr] = true
        return update_range_highlight(bufnr, topline, botline)
      end
    end,
  })
end

return {
  setup = setup_hide_leading_stars,
}

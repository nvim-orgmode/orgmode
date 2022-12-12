local config = require('orgmode.config')

local function apply(namespace, bufnr, line_index)
  if not config.org_hide_leading_stars then
    return
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, line_index, line_index + 1, false)[1]
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

return {
  apply = apply,
}

local config = require('orgmode.config')

local function update_line_highlight(namespace, bufnr, line_index, line)
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

local function apply(namespace, bufnr, changed_lines, first_line, _)
  if not config.org_hide_leading_stars then
    return
  end

  for i, line in ipairs(changed_lines) do
    update_line_highlight(namespace, bufnr, first_line + i - 1, line)
  end
end

return {
  apply = apply,
}

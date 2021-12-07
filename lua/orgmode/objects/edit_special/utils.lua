local config = require('orgmode.config')

local utils = {}

utils.make_temp_buf = function()
  local option = config.org_src_window_setup
  if type(option) == 'string' then
    vim.cmd(option)
  elseif type(option) == 'function' then
    option()
  else
    utils.echo_error("Invalid 'org_src_window_setup' setting, value is not a 'string' or 'function'")
    return false
  end

  return vim.api.nvim_get_current_buf()
end

return utils

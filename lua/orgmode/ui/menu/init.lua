local config = require('orgmode.config')
local utils = require('orgmode.utils')

local Menu = {}

Menu.open = function(title, items, prompt)
  if config.ui.menu.custom then
    return config.ui.menu.custom(title, items, prompt)
  end

  local preset = config.ui.menu.preset
  local ok, menu = pcall(require, 'orgmode.ui.menu.' .. preset)
  if ok then
    return menu:new(config.ui.menu):open(title, items, prompt)
  else
    utils.echo_error(string.format('The "%s" menu preset was not found', preset))
  end
end

return Menu

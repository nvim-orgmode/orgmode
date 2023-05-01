local config = require('orgmode.config')

local Menu = {}

function Menu._default_menu(title, items, prompt)
  local content = { title .. '\\n' .. string.rep('-', #title) }
  local valid_keys = {}
  for _, item in ipairs(items) do
    if item.separator then
      table.insert(content, string.rep(item.separator or '-', item.length))
    else
      valid_keys[item.key] = item
      table.insert(content, string.format('%s %s', item.key, item.label))
    end
  end
  prompt = prompt or 'key'
  table.insert(content, prompt .. ': ')
  vim.cmd(string.format('echon "%s"', table.concat(content, '\\n')))
  local char = vim.fn.nr2char(vim.fn.getchar())
  vim.cmd([[redraw!]])
  local entry = valid_keys[char]
  if not entry or not entry.action then
    return
  end
  return entry.action()
end

--- Open the menu for selecting one of the options
---@param title string Displayed title of the menu
---@param items MenuItem|MenuSeparator[] Displayed elements
---@param prompt string Prompt that will be shown
function Menu.open(title, items, prompt)
  local custom_handler = config.ui.menu.handler
  if custom_handler then
    return custom_handler(title, items, prompt)
  else
    return Menu._default_menu(title, items, prompt)
  end
end

return Menu

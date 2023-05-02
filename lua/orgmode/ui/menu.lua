local config = require('orgmode.config')

---@class MenuOption
---@field label string
---@field key string
---@field action? function

---@class MenuSeparator
---@field icon string?
---@field length number?

---@alias MenuItem MenuOption | MenuSeparator

---@class Menu
---@field title string
---@field items MenuItem[]?
---@field prompt string
---@field separator MenuSeparator?
local Menu = {}

---@param data Menu
function Menu:new(data)
  self:_validate_data(data)

  local opts = {}
  opts.title = data.title
  opts.prompt = data.prompt
  opts.items = data.items or {}
  opts.separator = data.separator or { icon = '-', length = 80 }

  setmetatable(opts, self)
  self.__index = self
  return opts
end

---@param option MenuOption
function Menu:_validate_option(option)
  vim.validate({
    label = { option.label, 'string' },
    key = { option.key, 'string' },
    action = { option.action, 'function', true },
  })
end

---@param items MenuItem[]?
function Menu:_validate_items(items)
  vim.validate({
    items = { items, 'table', true },
  })
  if not items then
    return
  end

  for _, item in ipairs(items) do
    if item.icon then
      ---@cast item MenuSeparator
      self:_validate_separator(item)
    else
      ---@cast item MenuOption
      self:_validate_option(item)
    end
  end
end

---@param separator MenuSeparator?
function Menu:_validate_separator(separator)
  vim.validate({
    separator = { separator, 'table', true },
  })
  if separator then
    vim.validate({
      icon = { separator.icon, 'string', true },
      length = { separator.length, 'number', true },
    })
  end
end

---@param data Menu
function Menu:_validate_data(data)
  vim.validate({
    title = { data.title, 'string' },
    prompt = { data.prompt, 'string' },
  })
  self:_validate_items(data.items)
  self:_validate_separator(data.separator)
end

---@param option MenuOption
function Menu:add_option(option)
  self:_validate_option(option)
  table.insert(self.items, option)
end

---@param separator MenuSeparator
function Menu:add_separator(separator)
  self:_validate_separator(separator)
  table.insert(self.items, vim.tbl_deep_extend('force', self.separator, separator))
end

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

function Menu:open()
  local menu_data = {
    title = self.title,
    items = self.items,
    prompt = self.prompt,
  }
  local custom_handler = config.ui.menu.handler
  if custom_handler then
    return custom_handler(menu_data)
  else
    return Menu._default_menu(menu_data)
  end
end

return Menu

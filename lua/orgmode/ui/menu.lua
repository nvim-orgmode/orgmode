local validator = require('orgmode.utils.validator')
local config = require('orgmode.config')

---@class OrgMenuOption
---@field label string Description of the action
---@field key string Key that will be processed when the keys are pressed in the menu
---@field action? function Handler that will be called when the `key` is pressed in the menu.

---@class OrgMenuSeparator
---@field icon string? Character used as separator. The default character is `-`
---@field length number? Number of repetitions of the separator character. The default length is 80

---@alias OrgMenuItem OrgMenuOption | OrgMenuSeparator

---@class OrgMenuOpts
---@field title string Menu title
---@field items OrgMenuItem[]? Menu items, may include options and separators
---@field prompt string Prompt text used to prompt a keystroke
---@field separator OrgMenuSeparator? Default separator

--- Menu for selecting an action by pressing a key by the user
---@class OrgMenu:OrgMenuOpts
local Menu = {}

---@param data OrgMenuOpts
---@return OrgMenu
function Menu:new(data)
  self:_validate_data(data)

  local opts = {}
  opts.title = data.title
  opts.prompt = data.prompt
  opts.items = data.items or {}
  opts.separator = vim.tbl_deep_extend('force', { icon = '-', length = 80 }, data.separator or {})

  setmetatable(opts, self)
  self.__index = self
  return opts
end

---@param option OrgMenuOption
function Menu:_validate_option(option)
  validator.validate('label', option.label, 'string')
  validator.validate('key', option.key, 'string')
  validator.validate('action', option.action, 'function', true)
end

---@param items OrgMenuItem[]?
function Menu:_validate_items(items)
  validator.validate('items', items, 'table', true)
  if not items then
    return
  end

  for _, item in ipairs(items) do
    if item.icon then
      ---@cast item OrgMenuSeparator
      self:_validate_separator(item)
    else
      ---@cast item OrgMenuOption
      self:_validate_option(item)
    end
  end
end

---@param separator OrgMenuSeparator?
function Menu:_validate_separator(separator)
  validator.validate('separator', separator, 'table', true)
  if separator then
    validator.validate('icon', separator.icon, 'string', true)
    validator.validate('length', separator.length, 'number', true)
  end
end

---@param data OrgMenuOpts
function Menu:_validate_data(data)
  validator.validate('title', data.title, 'string')
  validator.validate('prompt', data.prompt, 'string')
  self:_validate_items(data.items)
  self:_validate_separator(data.separator)
end

---@param option OrgMenuOption
function Menu:add_option(option)
  self:_validate_option(option)
  table.insert(self.items, option)
end

---@param separator? OrgMenuSeparator
function Menu:add_separator(separator)
  self:_validate_separator(separator)
  table.insert(self.items, vim.tbl_deep_extend('force', self.separator, separator or {}))
end

---@class OrgMenuData
---@field title string Menu title
---@field items OrgMenuItem[] Menu items, may include options and separators
---@field prompt string Prompt text used to prompt a keystroke

---@param data OrgMenuData
function Menu._default_menu(data)
  local content = { data.title, string.rep('-', #data.title) }
  local valid_keys = {}

  for _, item in ipairs(data.items) do
    if item.icon then
      ---@cast item OrgMenuSeparator
      table.insert(content, string.rep(item.icon, item.length))
    else
      ---@cast item OrgMenuOption
      valid_keys[item.key] = item
      table.insert(content, string.format('%s %s', item.key, item.label))
    end
  end

  table.insert(content, data.prompt .. ': ')

  vim.cmd(string.format('echon "%s"', table.concat(content, '\\n')))
  local char = vim.fn.nr2char(vim.fn.getchar())
  vim.cmd('redraw!')

  local entry = valid_keys[char]
  if not entry or not entry.action then
    return
  end
  return entry.action()
end

---@return table<string, OrgMenuOption | OrgMenuSeparator>
function Menu:get_valid_keys()
  local valid_keys = {}
  for _, item in ipairs(self.items) do
    if item.key then
      valid_keys[item.key] = item
    end
  end
  return valid_keys
end

function Menu:get_entry_by_key(key)
  return self:get_valid_keys()[key]
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

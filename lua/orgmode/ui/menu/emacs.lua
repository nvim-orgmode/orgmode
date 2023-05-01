local EmacsMenu = {}

function EmacsMenu:new()
  local opts = {}
  setmetatable(opts, self)
  self.__index = self
  return opts
end

function EmacsMenu:open(title, items, prompt)
  local content = { title .. '\\n' .. string.rep('-', #title) }
  local valid_keys = {}
  for _, item in ipairs(items) do
    if item.separator then
      table.insert(content, string.rep(item.separator or '-', item.length or 80))
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

return EmacsMenu

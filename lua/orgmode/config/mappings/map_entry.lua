---@class OrgMenuKeymap
---@field key string Keys typed after the mapping's lhs
---@field desc string
---@field action? fun() Without an action, the keys only label a group of further keymaps

---@class OrgMapEntry
---@field provided_opts table
---@field handler string
---@field handler_cmd string
---@field args table[]
---@field modes table[]
---@field opts table
---@field type table
---@field desc string
---@field help_desc? string
---@field menu_keymaps? fun(): OrgMenuKeymap[] Entries of the menu the handler opens
local MapEntry = {}

---@param handler string
---@param opts? table
function MapEntry.action(handler, opts)
  opts = opts or {}
  local action = { ('"%s"'):format(handler) }

  if opts.args then
    for _, arg in ipairs(opts.args) do
      table.insert(action, ('"%s"'):format(arg))
    end
    opts.args = nil
  end

  local formatted_action = ('<cmd>lua require("orgmode").action(%s)<CR>'):format(table.concat(action, ','))

  return MapEntry:new(formatted_action, opts)
end

function MapEntry.text_object(handler, opts)
  return MapEntry:new((':<C-U>lua require("orgmode.org.text_objects").%s()<CR>'):format(handler), {
    opts = opts,
    type = 'operator',
    modes = { 'x' },
  })
end

function MapEntry.custom(handler, opts)
  return MapEntry:new(handler, opts)
end

function MapEntry:with_handler(handler)
  local map_entry = MapEntry:new(self.handler, self.provided_opts)
  map_entry.handler = handler
  return map_entry
end

---@param handler string|function
---@param opts? table<string, any>
function MapEntry:new(handler, opts)
  opts = opts or {}
  vim.validate('handler', handler, { 'string', 'function' })
  vim.validate('modes', opts.modes, 'table', true)
  vim.validate('desc', opts.desc, 'string', true)
  vim.validate('help_desc', opts.help_desc, 'string', true)
  vim.validate('type', opts.type, 'string', true)

  local data = {}
  data.provided_opts = opts
  data.handler = handler
  data.opts = vim.tbl_extend('keep', opts.opts or {}, {
    nowait = true,
    silent = true,
    buffer = true,
  })
  data.help_desc = data.opts.help_desc
  data.opts.help_desc = nil
  data.modes = opts.modes or { 'n' }
  data.type = opts.type or 'action'
  data.menu_keymaps = opts.menu_keymaps
  setmetatable(data, self)
  self.__index = self
  return data
end

---@private
---@param default_mapping string|table
---@param user_mapping? string|table
---@param opts? table
---@return string[] lhs_list, table map_opts
function MapEntry:_resolve(default_mapping, user_mapping, opts)
  local mapping = vim.deepcopy(default_mapping)
  if user_mapping ~= nil then
    mapping = vim.deepcopy(user_mapping)
  end

  -- Allow disabling specific mapping
  if not mapping then
    return {}, {}
  end

  if type(mapping) == 'string' then
    mapping = { mapping }
  end

  if type(mapping) ~= 'table' then
    error(
      'Invalid mapping provided for ' .. tostring(self.handler) .. '. Only string and array of strings can be provided',
      0
    )
  end

  local map_opts = vim.tbl_extend('force', self.opts, opts or {})

  local prefix = ''
  if map_opts.prefix then
    prefix = map_opts.prefix
    map_opts.prefix = nil
  end

  if type(user_mapping) == 'table' and user_mapping.desc then
    map_opts.desc = user_mapping.desc
  end

  local lhs_list = {}
  for _, map in ipairs(mapping) do
    if prefix ~= '' then
      map = map:gsub('<prefix>', prefix)
    end
    table.insert(lhs_list, map)
  end
  return lhs_list, map_opts
end

---@param default_mapping string|table
---@param user_mapping? string|table
---@param opts? table
function MapEntry:attach(default_mapping, user_mapping, opts)
  local lhs_list, map_opts = self:_resolve(default_mapping, user_mapping, opts)
  for _, map in ipairs(lhs_list) do
    vim.keymap.set(self.modes, map, self.handler, map_opts)
    if self.type == 'operator' then
      vim.keymap.set('o', map, (':normal v%s<CR>'):format(map), map_opts)
    end
  end
end

--- Map each menu entry under the mapping's keys. The keys themselves and
--- the groups only get a label, which tools like which-key show for a prefix.
---@param default_mapping string|table
---@param user_mapping? string|table
---@param opts? table
function MapEntry:attach_menu_keymaps(default_mapping, user_mapping, opts)
  local lhs_list, map_opts = self:_resolve(default_mapping, user_mapping, opts)
  if #lhs_list == 0 then
    return
  end
  -- Entries can extend each other (custom agenda keys "a" and "ab"), so none may skip waiting for the longer one
  map_opts.nowait = false
  local keymaps = self.menu_keymaps()
  for _, map in ipairs(lhs_list) do
    vim.keymap.set(self.modes, map, '<Nop>', map_opts)
    for _, keymap in ipairs(keymaps) do
      local keymap_opts = vim.tbl_extend('force', map_opts, { desc = keymap.desc })
      vim.keymap.set(self.modes, map .. keymap.key, keymap.action or '<Nop>', keymap_opts)
    end
  end
end

return MapEntry

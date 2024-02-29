---@class OrgMapEntry
---@field handler string
---@field handler_cmd string
---@field args table[]
---@field modes table[]
---@field opts table
---@field type table
---@field desc string
---@field help_desc? string
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

---@param handler string|function
---@param opts? table<string, any>
function MapEntry:new(handler, opts)
  opts = opts or {}
  vim.validate({
    handler = { handler, { 'string', 'function' } },
    modes = { opts.modes, 'table', true },
    desc = { opts.desc, 'string', true },
    help_desc = { opts.help_desc, 'string', true },
    type = { opts.type, 'string', true },
  })
  local data = {}
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
  setmetatable(data, self)
  self.__index = self
  return data
end

---@param default_mapping string|table
---@param user_mapping? string|table
---@param opts? table
function MapEntry:attach(default_mapping, user_mapping, opts)
  local mapping = vim.deepcopy(default_mapping)
  if user_mapping ~= nil then
    mapping = vim.deepcopy(user_mapping)
  end

  -- Allow disabling specific mapping
  if not mapping then
    return
  end

  if type(mapping) == 'string' then
    mapping = { mapping }
  end

  if type(mapping) ~= 'table' then
    error('Invalid mapping provided for ' .. self.handler .. '. Only string and array of strings can be provided')
  end

  local map_opts = vim.tbl_extend('force', self.opts, opts or {})

  local prefix = ''
  if map_opts.prefix then
    prefix = map_opts.prefix
    map_opts.prefix = nil
  end

  for _, map in ipairs(mapping) do
    if prefix ~= '' then
      map = map:gsub('<prefix>', prefix)
    end
    vim.keymap.set(self.modes, map, self.handler, map_opts)
    if self.type == 'operator' then
      vim.keymap.set('o', map, (':normal v%s<CR>'):format(map), map_opts)
    end
  end
end

return MapEntry

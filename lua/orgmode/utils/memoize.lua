---@alias MemoizeKey { file: OrgFile, id: string }

---@class OrgMemoize
---@field class table
---@field key_getter fun(self: table): MemoizeKey
---@field memoized_methods table<string, fun(self: table, ...): any>
---@field methods_to_memoize table<string, boolean>
local Memoize = {}
Memoize.__index = Memoize

---@return fun(method: string): boolean
function Memoize:new(class, key_getter)
  local this = setmetatable({
    class = class,
    key_getter = key_getter,
    memoized_methods = {},
    methods_to_memoize = {},
  }, Memoize)

  this:setup()

  return function(method)
    this.methods_to_memoize[method] = true
    return true
  end
end

function Memoize:setup()
  self.class.__index = function(_, key)
    local method = self.class[key]

    -- Not memoizable or not required to be memoized
    if type(method) ~= 'function' or not self.methods_to_memoize[key] then
      return method
    end

    -- Already memoized
    if self.memoized_methods[key] then
      return self.memoized_methods[key]
    end

    self.memoized_methods[key] = function(method_self, ...)
      local memoize_key = self.key_getter(method_self)
      local cache = self:_get_cache_for_key(memoize_key)
      local arg_key = key .. '_' .. table.concat({ ... }, '_')

      if not cache[arg_key] then
        local value = vim.F.pack_len(method(method_self, ...))
        cache[arg_key] = value
      end

      local cached_value = cache[arg_key]

      if cached_value then
        local result = { pcall(vim.F.unpack_len, cached_value) }
        if result[1] then
          return unpack(result, 2)
        end
      end
    end

    return self.memoized_methods[key]
  end
end

---@private
---@param memoize_key MemoizeKey
---@return string
function Memoize:_get_cache_for_key(memoize_key)
  local id = memoize_key.id
  -- The cache is stored on the file so that it is released together with it.
  -- A module-level weak table cannot do this: LuaJIT has no ephemeron support,
  -- and cached values reference the file they were built from, so every entry
  -- stayed reachable through its own value for the whole session.
  local file = memoize_key.file
  local version_key = file.metadata.mtime
  local entry = file.memoize_cache

  if not entry or entry.__version ~= version_key then
    entry = {
      __version = version_key,
    }
    file.memoize_cache = entry
  end

  if not entry[id] then
    entry[id] = {}
  end

  return entry[id]
end

return Memoize

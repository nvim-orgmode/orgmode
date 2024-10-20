---@alias MemoizeKey { file: OrgFile, id: string }

---@class OrgMemoize
---@field class table
---@field key_getter fun(self: table): MemoizeKey
---@field memoized_methods table<string, fun(self: table, ...): any>
---@field methods_to_memoize table<string, boolean>
local Memoize = {
  cache = setmetatable({}, { __mode = 'k' }),
}
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
  local filename = memoize_key.file.filename
  local version_key = memoize_key.file.metadata.mtime

  if not self.cache[filename] or self.cache[filename].__version ~= version_key then
    self.cache[filename] = {
      __version = version_key,
    }
  end

  if not self.cache[filename][id] then
    self.cache[filename][id] = {}
  end

  return self.cache[filename][id]
end

return Memoize

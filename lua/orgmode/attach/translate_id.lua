local Builtins = {}

---Translate an UUID ID into a folder-path.
---
---Default format for how Org translates ID properties to a path for
---attachments.  Useful if ID is generated with UUID.
---
---@param id string
---@return string | nil path
function Builtins.uuid_folder_format(id)
  if id:len() <= 2 then
    return nil
  end
  return ('%s/%s'):format(id:sub(1, 2), id:sub(3))
end

---Translate an ID based on a timestamp to a folder-path.
---
---Useful way of translation if ID is generated based on ISO8601 timestamp.
---Splits the attachment folder hierarchy into year+month and the rest.
---
---@param id string
---@return string | nil path
function Builtins.ts_folder_format(id)
  if id:len() <= 6 then
    return nil
  end
  return ('%s/%s'):format(id:sub(1, 6), id:sub(7))
end

---Return `__/X/ID` folder path as a dumb fallback.
---
---X is the first character in the ID string.
---
---This function may be appended to `org_attach_id_path_function_list` to
---provide a fallback for non-standard ID values that other functions in
---`org_attach_id_path_function_list` are unable to handle. For example,
---when the ID is too short for `org_attach_id_ts_folder_format`.
---
---However, we recommend to define a more specific function spreading entries
---over multiple folders.  This function may create a large number of entries
---in a single folder, which may cause issues on some systems."
---
---@param id string
---@return string path
function Builtins.fallback_folder_format(id)
  assert(id ~= '', id)
  return ('__/%s/%s'):format(id:sub(1, 1), id)
end

---This module is a function that evaluates `func`.
---
---If `func` is a string, look it up in this module's built-in functions and
---evaluate the result. If `func` is a function, evaluate it directly.
---
---In either case, `func` is called with a node's ID and should either return
---a path to its attachments directory, or return nil if that's not impossible.
---
---@param func string | fun(id: string): string?
---@param id string ID property
---@return string|nil attach_dir
return function(func, id)
  return (Builtins[func] or func)(id)
end

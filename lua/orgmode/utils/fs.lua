local utils = require('orgmode.utils')

local M = {}

---@param path_str string
---@return string | false
function M.substitute_path(path_str)
  if path_str:match('^/') then
    return path_str
  elseif path_str:match('^~/') then
    local home_path = os.getenv('HOME')
    return home_path and path_str:gsub('^~', home_path) or false
  elseif path_str:match('^%./') then
    local base = vim.fn.fnamemodify(utils.current_file_path(), ':p:h')
    return base .. '/' .. path_str:gsub('^%./', '')
  elseif path_str:match('^%.%./') then
    local base = vim.fn.fnamemodify(utils.current_file_path(), ':p:h')
    return base .. '/' .. path_str
  end
  return false
end

---@param filepath string
---@return string | false
function M.get_real_path(filepath)
  if not filepath then
    return false
  end
  local substituted = M.substitute_path(filepath)
  if not substituted then
    return false
  end
  local real = vim.uv.fs_realpath(substituted)
  if real and filepath:sub(-1, -1) == '/' then
    -- make sure if filepath gets a trailing slash, the realpath gets one, too.
    real = real .. '/'
  end
  return real or false
end

function M.get_current_file_dir()
  local current_file = utils.current_file_path()
  local current_dir = vim.fn.fnamemodify(current_file, ':p:h')
  return current_dir or ''
end

---@param paths string[]
---@return string[]
function M.trim_common_root(paths)
  local filepaths = vim.tbl_map(function(value)
    return vim.split(vim.fn.fnamemodify(value, ':h'), '/', { trimempty = true, plain = true })
  end, paths)

  table.sort(filepaths, function(a, b)
    return #a < #b
  end)

  local get_common_root = function()
    local common_root = {}
    local counter = 1

    while counter <= #filepaths[1] do
      local current = filepaths[1][counter]
      for _, filepath in ipairs(filepaths) do
        if filepath[counter] ~= current then
          return common_root
        end
      end
      table.insert(common_root, current)
      counter = counter + 1
    end

    return common_root
  end

  local common_root = get_common_root()

  if #common_root == 0 then
    return vim.tbl_map(function(path)
      return path:gsub('^/', '')
    end, paths)
  end

  local root = '/' .. table.concat(common_root, '/') .. '/'
  local result = {}
  for _, path in ipairs(paths) do
    local relative_path = path:sub(#root + 1)
    table.insert(result, relative_path)
  end
  return result
end

---Return a path to the same file as `filepath` but relative to `base`.
---Starting with nvim 0.11, we can replace this with `vim.fs.relpath()`.
---@param filepath string an absolute path
---@param base string an absolute path to an ancestor of filepath;
---                   here, `'.'` represents the current working directory, and
---                   *not* the current file's directory.
---@return string filepath_relative_to_base
function M.make_relative(filepath, base)
  vim.validate({
    filepath = { filepath, 'string', false },
    base = { base, 'string', false },
  })
  filepath = vim.fn.fnamemodify(filepath, ':p')
  base = vim.fn.fnamemodify(base, ':p')
  if base:sub(-1) ~= '/' then
    base = base .. '/'
  end
  local levels_up = 0
  for parent in vim.fs.parents(base) do
    if parent:sub(-1) ~= '/' then
      parent = parent .. '/'
    end
    if vim.startswith(filepath, parent) then
      filepath = filepath:sub(parent:len() + 1)
      if levels_up > 0 then
        return vim.fs.joinpath(string.rep('..', levels_up, '/'), filepath)
      end
      return vim.fs.joinpath('.', filepath)
    end
    levels_up = levels_up + 1
  end
  -- No common root, just return the absolute path.
  return filepath
end

return M

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

--Convert absolute path to the same format as source path
--If source path has relative parts, like ~, ./ or ../,
--apply same to the long path and return
---@param source_path string
---@param long_path string
function M.convert_path(source_path, long_path)
  if source_path:match('^/') then
    return long_path
  end

  if source_path:match('^~/') then
    local home_path = os.getenv('HOME')
    if home_path then
      return long_path:gsub('^' .. vim.pesc(home_path), '~')
    end
    return long_path
  end

  if source_path:match('^%./') then
    local base = vim.fn.fnamemodify(utils.current_file_path(), ':p:h')
    return long_path:gsub('^' .. vim.pesc(base), '.')
  end

  if source_path:match('^%.%./') then
    local base = vim.fn.fnamemodify(utils.current_file_path(), ':p:h:h')
    return long_path:gsub('^' .. vim.pesc(base), '..')
  end

  return long_path
end

---@param filepath string
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

return M

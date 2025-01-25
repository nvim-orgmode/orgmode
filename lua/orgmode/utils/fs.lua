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
  local filepaths = vim.deepcopy(paths)
  table.sort(filepaths, function(a, b)
    local _, count_a = a:gsub('/', '')
    local _, count_b = b:gsub('/', '')
    return count_a < count_b
  end)

  local result = {}
  local root = vim.fn.fnamemodify(filepaths[1], ':h') .. '/'

  for _, path in ipairs(paths) do
    local relative_path = path:sub(#root + 1)
    table.insert(result, relative_path)
  end
  return result
end

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

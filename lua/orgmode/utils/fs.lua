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
  local real = vim.loop.fs_realpath(substituted)
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
  local root = vim.pesc(vim.fn.fnamemodify(filepaths[1], ':h')) .. '/'

  for _, path in ipairs(paths) do
    local relative_path = path:sub(#root + 1)
    table.insert(result, relative_path)
  end
  return result
end

return M

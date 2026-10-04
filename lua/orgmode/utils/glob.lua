local Promise = require('orgmode.utils.promise')

local M = {}

-- Max time (ms) to spend finding files before yielding back to the event loop
local WORK_BUDGET_MS = 5
-- `**` matches any number of directories, the walk still needs a limit
local MAX_RECURSIVE_DEPTH = 100
local SLASH = string.byte('/')

---@param since integer `vim.uv.hrtime()` value
---@return number
local function ms_since(since)
  return (vim.uv.hrtime() - since) / 1e6
end

-- '/' sorts first, so 'org/x.org' comes before 'org-old/x.org', as in `vim.fn.glob()`
---@param byte integer
---@return integer
local function rank(byte)
  return byte == SLASH and 0 or byte
end

---Same order as `vim.fn.glob()`
---@param a string
---@param b string
---@return boolean
local function compare_paths(a, b)
  if vim.o.fileignorecase then
    a, b = a:upper(), b:upper()
  end
  for i = 1, math.min(#a, #b) do
    local c1, c2 = a:byte(i), b:byte(i)
    if c1 ~= c2 then
      return rank(c1) < rank(c2)
    end
  end
  -- One path is a prefix of the other
  return #a < #b
end

---@param path string
---@return boolean
local function is_hidden(path)
  return path:match('[^/]+$'):sub(1, 1) == '.'
end

---Same check as `vim.fn.glob()` does with 'wildignore': against the full path and the file name
---@return fun(path: string): boolean
local function wildignore_matcher()
  local regexes = {}
  local case_prefix = vim.o.fileignorecase and '\\c' or ''
  for _, pattern in ipairs(vim.split(vim.o.wildignore, ',', { trimempty = true })) do
    local ok, regex = pcall(vim.regex, case_prefix .. vim.fn.glob2regpat(pattern))
    if ok then
      table.insert(regexes, regex)
    end
  end
  return function(path)
    local name = path:match('[^/]+$')
    for _, regex in ipairs(regexes) do
      if regex:match_str(path) or regex:match_str(name) then
        return true
      end
    end
    return false
  end
end

---@return async fun()
local function yielder()
  local started = vim.uv.hrtime()
  return function()
    if ms_since(started) >= WORK_BUDGET_MS then
      Promise.yield():await()
      started = vim.uv.hrtime()
    end
  end
end

---@class OrgGlobContext
---@field filter fun(path: string): boolean
---@field is_ignored fun(path: string): boolean
---@field maybe_yield fun()

---@async
---@param root string Directory to walk
---@param rest string Pattern for paths relative to `root`
---@param ctx OrgGlobContext
---@return string[]
local function walk(root, rest, ctx)
  local ignore_case = vim.o.fileignorecase
  local matcher = vim.glob.to_lpeg(ignore_case and rest:lower() or rest)
  local depth = rest:find('**', 1, true) and MAX_RECURSIVE_DEPTH or #vim.split(rest, '/')
  local allow_hidden = rest:find('^%.') or rest:find('/%.')
  local is_visible = function(name)
    return allow_hidden or not is_hidden(name)
  end

  local files = {}
  for name, type in vim.fs.dir(root, { depth = depth, follow = true, skip = is_visible }) do
    if is_visible(name) and ctx.filter(name) and matcher:match(ignore_case and name:lower() or name) then
      local file = vim.fs.joinpath(root, name)
      -- Symlinks are only resolved when they match
      local is_file = type == 'file' or (vim.uv.fs_stat(file) or {}).type == 'file'
      if is_file and not ctx.is_ignored(file) then
        table.insert(files, file)
      end
    end
    ctx.maybe_yield()
  end

  table.sort(files, compare_paths)
  return files
end

---@async
---@param pattern string
---@param ctx OrgGlobContext
---@return string[]
local function find_one(pattern, ctx)
  -- A trailing slash only matches directories
  if vim.endswith(pattern, '/') then
    return {}
  end
  local path = vim.fn.fnamemodify(vim.fs.normalize(pattern), ':p')
  -- Walk from the directory before the first wildcard, and match the rest of the pattern
  local root, rest = path:match('^(.-)/([^/]*[%*%?%[{].*)$')
  if root then
    return walk(root == '' and '/' or root, rest, ctx)
  end

  ctx.maybe_yield()
  if not ctx.filter(path) or ctx.is_ignored(path) then
    return {}
  end
  local stat = vim.uv.fs_stat(path)
  return (stat and stat.type == 'file') and { path } or {}
end

---Results per pattern are sorted like `vim.fn.glob()`, 'suffixes' is not applied.
---Yields to the event loop while walking, so it must run inside `Promise.async`.
---@async
---@param patterns string[]
---@param filter fun(path: string): boolean Runs before stat, on a path relative to the walk root or a literal path
---@return string[]
function M.find(patterns, filter)
  local ctx = { filter = filter, is_ignored = wildignore_matcher(), maybe_yield = yielder() }
  local files = {}
  for _, pattern in ipairs(patterns) do
    vim.list_extend(files, find_one(pattern, ctx))
  end
  return files
end

return M

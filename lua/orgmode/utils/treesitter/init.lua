local M = {}
---@type table<string, vim.treesitter.Query>
local query_cache = {}

-- Reload treesitter highlighter without triggering FileType autocommands that include reloading entire file
function M.restart_highlights(bufnr)
  bufnr = bufnr or 0
  vim.treesitter.stop(bufnr)
  vim.treesitter.start(bufnr, 'org')
end

function M.parse_current_file()
  return vim.treesitter.get_parser(0, 'org', {}):parse()
end

---@param opts? vim.treesitter.get_node.Opts
function M.get_node(opts)
  opts = opts or {}
  opts.lang = opts.lang or 'org'
  return vim.treesitter.get_node(opts)
end

---@param cursor? table
---@return TSNode | nil
function M.get_node_at_cursor(cursor)
  M.parse_current_file()
  if not cursor then
    return M.get_node()
  end

  return M.get_node({
    bufnr = 0,
    pos = { cursor[1] - 1, cursor[2] },
  })
end

-- walks the tree to find a headline
function M.find_headline(node)
  if node:type() == 'headline' then
    return node
  end

  if node:type() == 'section' then
    -- The headline is always the first child of a section
    return node:field('headline')[1]
  end

  if node:parent() then
    return M.find_headline(node:parent())
  end

  return nil
end

-- returns the nearest headline
function M.closest_headline_node(cursor)
  local node = M.get_node_at_cursor(cursor)

  if not node then
    return nil
  end

  return M.find_headline(node)
end

---@param node TSNode | nil
---@param node_type string | string[]
---@return TSNode | nil
function M.closest_node(node, node_type)
  if not node then
    return nil
  end
  local types = type(node_type) == 'table' and node_type or { node_type }

  for _, t in ipairs(types) do
    if node:type() == t then
      return node
    end
  end

  return M.closest_node(node:parent(), types)
end

---@param node? TSNode
---@return TSNode[]
function M.get_named_children(node)
  local nodes = {}
  if not node then
    return nodes
  end
  for i = 0, node:named_child_count() - 1, 1 do
    nodes[i + 1] = node:named_child(i)
  end
  return nodes
end

---@return vim.treesitter.Query
function M.get_query(query)
  local ts_query = query_cache[query]
  if not ts_query then
    ts_query = vim.treesitter.query.parse('org', query)
    query_cache[query] = ts_query
  end
  return ts_query
end

---@param node TSNode | nil
---@param type string
---@return TSNode | nil
function M.parents_until(node, type)
  local parent = node

  while parent do
    if parent:type() == type then
      return parent
    end
    parent = parent:parent()
  end
end

---@param node TSNode
---@param drawer string
---@param source? number|string
---@return boolean
function M.is_date_in_drawer(node, drawer, source)
  if
    (node:parent() and node:parent():type() == 'contents')
    and (node:parent():parent() and node:parent():parent():type() == 'drawer')
  then
    local drawer_node = node:parent():parent() --[[@as TSNode]]
    local drawer_name = vim.treesitter.get_node_text(drawer_node:field('name')[1], source or 0)
    return drawer_name:lower() == drawer
  end

  return false
end

function M.node_to_lsp_range(node)
  local start_line, start_col, end_line, end_col = vim.treesitter.get_node_range(node)
  local rtn = {}
  rtn.start = { line = start_line, character = start_col }
  rtn['end'] = { line = end_line, character = end_col }
  return rtn
end

---Return the range of the given node, but override the start column to be 0.
---This is needed when we want to parse the lines manually to ensure that
---we parse from the start of the line
---@param node TSNode
---@return number[]
function M.range_with_zero_start_col(node)
  local range = { node:range() }
  range[2] = 0
  return range
end

-- Memoizes a function based on the buffer tick of the provided bufnr.
-- The cache entry is cleared when the buffer is detached to avoid memory leaks.
-- The options argument is a table with one optional value:
--  - key: extracts the cache key from the given arguments.
---@param fn function the fn to memoize, taking the buffer as first argument
---@param options? {key: string|fun(...): string?} the memoization options
---@return function: a memoized function
function M.memoize_by_buf_tick(fn, options)
  options = options or {}

  ---@type table<string, {result: any, last_tick: integer}>
  local cache = setmetatable({}, { __mode = 'kv' })
  local key_fn = options.key or function(a)
    return a
  end

  return function(bufnr, ...)
    local key = key_fn(bufnr, ...) or ''
    local tick = vim.api.nvim_buf_get_changedtick(bufnr)

    if cache[key] then
      if cache[key].last_tick == tick then
        return cache[key].result
      end
    else
      local function detach_handler()
        cache[key] = nil
      end

      -- Clean up logic only!
      vim.api.nvim_buf_attach(bufnr, false, {
        on_detach = detach_handler,
        on_reload = detach_handler,
      })
    end

    cache[key] = {
      result = fn(bufnr, ...),
      last_tick = tick,
    }

    return cache[key].result
  end
end

return M

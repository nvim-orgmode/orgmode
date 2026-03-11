local config = require('orgmode.config')

---@type table<string, { mtime_sec: number, items: OrgCitationItem[] }>
local _cache = {}

---@param content string
---@return OrgCitationItem[]
local function parse_bibtex(content)
  local items = {}
  for entry_type, key in content:gmatch('@(%a%w*)%s*[{(]%s*([^%s,}%)]+)') do
    local lt = entry_type:lower()
    if lt ~= 'string' and lt ~= 'preamble' and lt ~= 'comment' then
      table.insert(items, { key = key })
    end
  end
  return items
end

---@param path string
---@return OrgCitationItem[]
local function parse_file(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return {}
  end
  local mtime_sec = stat.mtime.sec
  local cached = _cache[path]
  if cached and cached.mtime_sec == mtime_sec then
    return cached.items
  end
  local lines = vim.fn.readfile(path)
  local items = parse_bibtex(table.concat(lines, '\n'))
  _cache[path] = { mtime_sec = mtime_sec, items = items }
  return items
end

---@param raw string
---@param base_dir? string
---@return string
local function resolve_path(raw, base_dir)
  raw = vim.trim(raw)
  if raw:sub(1, 1) == '~' then
    return vim.fn.expand(raw)
  end
  if raw:sub(1, 1) ~= '/' then
    local base = base_dir or vim.fn.getcwd()
    return vim.fn.fnamemodify(base .. '/' .. raw, ':p')
  end
  return raw
end

---@class OrgCitationBibtex:OrgCitationSource
---@field private files OrgFiles | nil
local OrgCitationBibtex = {}
OrgCitationBibtex.__index = OrgCitationBibtex

---@param opts { files: OrgFiles | nil }
function OrgCitationBibtex:new(opts)
  return setmetatable({ files = opts and opts.files or nil }, OrgCitationBibtex)
end

---@return string
function OrgCitationBibtex:get_name()
  return 'bibtex'
end

---@return OrgCitationItem[]
function OrgCitationBibtex:get_items()
  local items = {}
  for _, path in ipairs(self:_get_bib_paths()) do
    vim.list_extend(items, parse_file(path))
  end
  return items
end

---Open the .bib file at the entry for the given key.
---@param key string
---@return boolean
function OrgCitationBibtex:follow(key)
  for _, path in ipairs(self:_get_bib_paths()) do
    local lnum = self:_find_key_line(path, key)
    if lnum then
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
      vim.fn.cursor(lnum, 1)
      return true
    end
  end
  return false
end

---Collect readable .bib paths from the global config and file-local #+bibliography: directives.
---@private
---@return string[]
function OrgCitationBibtex:_get_bib_paths()
  local paths = {}
  local seen = {}

  local function add(raw, base_dir)
    local resolved = resolve_path(raw, base_dir)
    if not seen[resolved] and vim.fn.filereadable(resolved) == 1 then
      seen[resolved] = true
      table.insert(paths, resolved)
    end
  end

  local global = config.citations.org_cite_global_bibliography
  if global then
    if type(global) == 'string' then
      add(global, nil)
    else
      for _, p in ipairs(global) do
        add(p, nil)
      end
    end
  end

  if self.files then
    local current_filename = vim.fn.expand('%:p')
    if current_filename ~= '' then
      local file = self.files:load_file_sync(current_filename)
      if file then
        local file_dir = vim.fn.fnamemodify(file.filename, ':p:h')
        local directives = file:_get_directive('bibliography', true)
        if directives then
          if type(directives) == 'string' then
            directives = { directives }
          end
          for _, raw in ipairs(directives) do
            add(raw, file_dir)
          end
        end
      end
    end
  end

  return paths
end

---@private
---@param path string
---@param key string
---@return number | nil
function OrgCitationBibtex:_find_key_line(path, key)
  local lines = vim.fn.readfile(path)
  local escaped = vim.pesc(key)
  local suffix_pat = '[%s,}%)]'
  for i, line in ipairs(lines) do
    if line:match('@%a%w*%s*[{(]%s*' .. escaped .. suffix_pat) or line:match('@%a%w*%s*[{(]%s*' .. escaped .. '$') then
      return i
    end
  end
  return nil
end

return OrgCitationBibtex

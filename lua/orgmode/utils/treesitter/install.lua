local Promise = require('orgmode.utils.promise')
local utils = require('orgmode.utils')
local uv = vim.uv
local M = {
  compilers = { 'tree-sitter', vim.fn.getenv('CC'), 'cc', 'gcc', 'clang', 'cl', 'zig' },
}

local required_version = '2.1.0'

function M.install()
  if vim.fn.has('win32') == 1 then
    M.cleanup_old_parsers()
  end

  local version_info = M.get_version_info()

  if not version_info.installed then
    return M.run('install')
  end

  if #version_info.parser_locations > 1 then
    M.notify_conflicting_parsers(version_info.parser_locations)
  end

  if not version_info.installed_in_orgmode_dir then
    return false
  end

  if version_info.outdated then
    return M.run('update')
  end

  if version_info.version_mismatch then
    return M.reinstall()
  end

  return false
end

function M.notify_conflicting_parsers(conflicting_parsers)
  local list = vim.tbl_map(function(parser)
    return ('- `%s`'):format(parser)
  end, conflicting_parsers)
  utils.notify(
    ('Multiple org parsers found in these locations:\n%s\nDelete unused ones to avoid conflicts.'):format(
      table.concat(list, '\n')
    ),
    {
      level = 'warn',
      timeout = 5000,
    }
  )
end

function M.reinstall()
  return M.run('reinstall')
end

function M.get_version_info()
  local result = {
    installed = false,
    installed_version = nil,
    outdated = false,
    required_version = required_version,
    version_mismatch = false,
    parser_locations = {},
    installed_in_orgmode_dir = false,
  }

  if M.not_installed() then
    return result
  end

  result.installed = true

  local parser_locations = M.get_parser_locations()
  result.parser_locations = parser_locations.parser_locations
  result.installed_in_orgmode_dir = parser_locations.installed_in_orgmode_dir

  if not result.installed_in_orgmode_dir then
    return result
  end

  local installed_version = M.get_installed_version()
  result.installed_version = installed_version
  result.outdated = vim.version.lt(installed_version, required_version)
  result.version_mismatch = installed_version ~= required_version

  return result
end

function M.get_parser_locations()
  local runtime_files = vim.api.nvim_get_runtime_file('parser/org.so', true)
  local parser_locations = {}
  local valid_paths = {}
  for _, runtime_file in ipairs(runtime_files) do
    local path = vim.fn.fnamemodify(runtime_file, ':p')
    if not valid_paths[path] then
      valid_paths[path] = path
      table.insert(parser_locations, path)
    end
  end

  local installed_in_orgmode_dir = false

  if #parser_locations == 1 and vim.fs.normalize(parser_locations[1]) == vim.fs.normalize(M.get_parser_path()) then
    installed_in_orgmode_dir = true
  end

  return {
    parser_locations = parser_locations,
    installed_in_orgmode_dir = installed_in_orgmode_dir,
  }
end

function M.not_installed()
  local ok, result, err = pcall(vim.treesitter.language.add, 'org')
  return not ok or (not result and err ~= nil)
end

function M._write_lock_file(content)
  local lock_file = M.get_lock_file()
  local file = assert(io.open(lock_file, 'w'))
  file:write(vim.json.encode(content))
  file:close()
end

function M.get_installed_version()
  local lock_file = M.get_lock_file()
  if not vim.uv.fs_stat(lock_file) then
    M._write_lock_file({ version = '1.3.4' })
    return '1.3.4'
  end
  local lock_file_handle = assert(io.open(lock_file, 'r'))
  local file_content = vim.json.decode(lock_file_handle:read('*a'))
  lock_file_handle:close()
  return file_content.version
end

function M.get_package_path()
  -- Path to this source file, removing the leading '@'
  local source = string.sub(debug.getinfo(1, 'S').source, 2)

  -- Path to the package root
  return vim.fn.fnamemodify(source, ':p:h:h:h:h:h')
end

function M.get_lock_file()
  return vim.fs.joinpath(M.get_package_path(), '.org-ts-lock.json')
end

function M.get_parser_path()
  return vim.fs.joinpath(M.get_package_path(), 'parser', 'org.so')
end

function M.select_compiler_args(compiler)
  if compiler == 'tree-sitter' then
    return {
      'build',
      '-o',
      'parser.so',
    }
  end
  if string.match(compiler, 'cl$') or string.match(compiler, 'cl.exe$') then
    return {
      '/Fe:',
      'parser.so',
      '/Isrc',
      'src/parser.c',
      'src/scanner.c',
      '-Os',
      '/std:c11',
      '/utf-8',
      '/LD',
    }
  elseif string.match(compiler, 'zig$') or string.match(compiler, 'zig.exe$') then
    return {
      'c++',
      '-o',
      'parser.so',
      'src/parser.c',
      'src/scanner.c',
      '-lc',
      '-Isrc',
      '-shared',
      '-Os',
      '-std=c11',
    }
  else
    local args = {
      '-o',
      'parser.so',
      '-I./src',
      'src/parser.c',
      'src/scanner.c',
      '-Os',
      '-std=c11',
    }
    if vim.fn.has('mac') == 1 then
      table.insert(args, '-bundle')
    else
      table.insert(args, '-shared')
    end
    if vim.fn.has('win32') == 0 then
      table.insert(args, '-fPIC')
    end
    return args
  end
end

function M.exe(cmd, opts)
  return Promise.new(function(resolve)
    vim.system(utils.concat({ cmd }, opts.args or {}), {
      cwd = opts.cwd,
    }, function(result)
      resolve(result.code, result.stderr)
    end)
  end)
end

-- Returns the move command based on the OS
---@param from string
---@param to string
---@param cwd string
---@param is_win boolean
---@param shellslash? boolean
function M.select_mv_cmd(from, to, cwd, is_win, shellslash)
  local _ = shellslash
  if is_win then
    local function cmdpath(p)
      local r = p:gsub('/', '\\')
      return r
    end

    return {
      cmd = 'cmd',
      opts = {
        args = { '/C', 'move', '/Y', cmdpath(from), cmdpath(to) },
        cwd = cwd,
      },
    }
  end

  return {
    cmd = 'mv',
    opts = {
      args = { '-f', from, to },
      cwd = cwd,
    },
  }
end

function M.get_old_parsers_dir()
  return vim.fs.joinpath(vim.fn.stdpath('cache'), 'orgmode-old-parsers')
end

---@param path string
---@return boolean
local function ensure_dir(path)
  local stat = uv.fs_stat(path)
  if stat then
    return stat.type == 'directory'
  end
  local parent = vim.fs.dirname(path)
  if parent and parent ~= path and not ensure_dir(parent) then
    return false
  end
  if uv.fs_mkdir(path, 493) then
    return true
  end
  stat = uv.fs_stat(path)
  return stat ~= nil and stat.type == 'directory'
end

---@param target_path? string
---@param backup_dir? string
function M.cleanup_old_parsers(target_path, backup_dir)
  target_path = target_path or M.get_parser_path()
  backup_dir = backup_dir or M.get_old_parsers_dir()

  local parser_dir = vim.fs.dirname(target_path)
  local parser_prefix = vim.fs.basename(target_path) .. '.'

  local function remove_matching(dir, predicate)
    if not dir then
      return
    end
    local stat = uv.fs_stat(dir)
    if not stat or stat.type ~= 'directory' then
      return
    end
    for name, entry_type in vim.fs.dir(dir) do
      if entry_type == 'file' and predicate(name) then
        pcall(uv.fs_unlink, vim.fs.joinpath(dir, name))
      end
    end
  end

  remove_matching(backup_dir, function(name)
    return vim.endswith(name, '.old')
  end)
  pcall(uv.fs_rmdir, backup_dir)

  remove_matching(parser_dir, function(name)
    return vim.startswith(name, parser_prefix) and vim.endswith(name, '.old')
  end)
end

---@param target_path string
---@param backup_dir? string
---@return string?
function M.backup_existing_parser(target_path, backup_dir)
  if not uv.fs_stat(target_path) then
    return nil
  end

  backup_dir = backup_dir or M.get_old_parsers_dir()
  local suffix = ('%d.%d.old'):format(uv.os_getpid(), uv.hrtime())
  local parser_name = vim.fs.basename(target_path)

  if ensure_dir(backup_dir) then
    local cache_backup = vim.fs.joinpath(backup_dir, ('%s.%s'):format(parser_name, suffix))
    if uv.fs_rename(target_path, cache_backup) then
      return cache_backup
    end
  end

  local local_backup = ('%s.%s'):format(target_path, suffix)
  local ok, err = uv.fs_rename(target_path, local_backup)
  if not ok then
    error(
      '[orgmode] Failed to move existing tree-sitter parser out of the way: ' .. (tostring(err) or 'Unknown error'),
      0
    )
  end
  return local_backup
end

---@param from string
---@param to string
---@param cwd string
---@param is_win boolean
---@param shellslash boolean
---@param backup_dir? string
---@return OrgPromise<integer>
function M.move_parser(from, to, cwd, is_win, shellslash, backup_dir)
  local backup_path = nil
  if is_win then
    M.cleanup_old_parsers(to, backup_dir)
    backup_path = M.backup_existing_parser(to, backup_dir)
  end

  local move_cmd = M.select_mv_cmd(from, to, cwd, is_win, shellslash)
  return M.exe(move_cmd.cmd, move_cmd.opts):next(function(code, err)
    if code ~= 0 then
      if backup_path then
        pcall(uv.fs_rename, backup_path, to)
      end
    elseif backup_path then
      pcall(uv.fs_unlink, backup_path)
    end
    return code, err
  end)
end

-- Get path to the directory that holds the tree-sitter grammar.
function M.get_path(url, type)
  local local_path = vim.fn.expand(url)
  local is_local_path = vim.fn.isdirectory(local_path) == 1

  if is_local_path then
    utils.notify('Using local version of tree-sitter grammar...', { id = 'orgmode-treesitter-install' })
    return Promise.resolve(local_path)
  end

  local path = vim.fs.joinpath(vim.fn.stdpath('cache'), 'tree-sitter-org')
  vim.fn.delete(path, 'rf')

  local msg = {
    install = 'Installing',
    update = 'Updating',
    reinstall = 'Reinstalling',
  }

  utils.notify(('%s tree-sitter grammar...'):format(msg[type]), { id = 'orgmode-treesitter-install' })
  return M.exe('git', {
    args = { 'clone', '--filter=blob:none', '--depth=1', '--branch=' .. required_version, url, path },
  }):next(function(code, err)
    if code ~= 0 then
      error('[orgmode] Failed to clone tree-sitter-org: ' .. (tostring(err) or 'Unknown error'), 0)
    end
    return path
  end)
end

---@param type? 'install' | 'update' | 'reinstall''
---@return OrgPromise<boolean>
function M.run(type)
  local url = 'https://github.com/nvim-orgmode/tree-sitter-org'
  local compiler = vim.tbl_filter(function(exe)
    return exe ~= vim.NIL and vim.fn.executable(exe) == 1
  end, M.compilers)[1]

  if not compiler then
    error('[orgmode] No C compiler found for installing tree-sitter grammar', 0)
  end

  local compiler_args = M.select_compiler_args(compiler)
  local ts_grammar_dir = nil
  local is_win = vim.fn.has('win32') == 1
  local shellslash = is_win and vim.opt.shellslash:get() or false
  local parser_path = M.get_parser_path()
  local old_parsers_dir = M.get_old_parsers_dir()

  return M.get_path(url, type)
    :next(function(directory)
      ts_grammar_dir = directory
      return M.exe(compiler, {
        args = compiler_args,
        cwd = directory,
      })
    end)
    :next(function(code, err)
      if code ~= 0 then
        error('[orgmode] Failed to compile parser: ' .. (tostring(err) or 'Unknown error'), 0)
      end
      return M.move_parser('parser.so', parser_path, ts_grammar_dir or '', is_win, shellslash, old_parsers_dir)
    end)
    :next(function(code, err)
      if code ~= 0 then
        error(
          '[orgmode] Failed to move generated tree-sitter parser to runtime folder: '
            .. (tostring(err) or 'Unknown error'),
          0
        )
      end
      return M._write_lock_file({ version = required_version })
    end)
    :next(vim.schedule_wrap(function()
      local msg = { 'Tree-sitter grammar installed!' }

      if type == 'update' then
        msg = {
          'Tree-sitter grammar updated!',
          'Please restart Neovim to apply the changes.',
        }
      end
      utils.notify(msg, {
        id = 'orgmode-treesitter-install',
      })
      vim.treesitter.language.add('org')
      return true
    end))
    :wait(60000)
end

return M

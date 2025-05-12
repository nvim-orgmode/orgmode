local Promise = require('orgmode.utils.promise')
local utils = require('orgmode.utils')
local uv = vim.uv
local M = {
  compilers = { vim.fn.getenv('CC'), 'cc', 'gcc', 'clang', 'cl', 'zig' },
}

local required_version = '2.0.0'

function M.install()
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

function M.get_installed_version()
  local lock_file = M.get_lock_file()
  -- No lock file, assume that version is 1.3.4 (when lock file was introduced)
  if not vim.uv.fs_stat(lock_file) then
    utils.writefile(lock_file, vim.json.encode({ version = '1.3.4' })):wait()
    return '1.3.4'
  end
  local file_content = vim.json.decode(utils.readfile(lock_file, { raw = true }):wait())
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
  if string.match(compiler, 'cl$') or string.match(compiler, 'cl.exe$') then
    return {
      '/Fe:',
      'parser.so',
      '/Isrc',
      'src/parser.c',
      'src/scanner.c',
      '-Os',
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
    }
  else
    local args = {
      '-o',
      'parser.so',
      '-I./src',
      'src/parser.c',
      'src/scanner.c',
      '-Os',
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
    local stdin = uv.new_pipe()
    local stdout = uv.new_pipe()
    local stderr = uv.new_pipe()
    opts.stdio = { stdin, stdout, stderr }
    uv.spawn(cmd, opts, function(code)
      resolve(code)
    end)
  end)
end

-- Returns the move command based on the OS
---@param from string
---@param to string
---@param cwd string
---@param is_win boolean
---@param shellslash boolean
function M.select_mv_cmd(from, to, cwd, is_win, shellslash)
  if is_win then
    local function cmdpath(p)
      if shellslash then
        local r = p:gsub('/', '\\')
        return r
      end
      return p
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
  }):next(function(code)
    if code ~= 0 then
      error('[orgmode] Failed to clone tree-sitter-org', 0)
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
  local lock_file = M.get_lock_file()
  local is_win = vim.fn.has('win32') == 1
  local shellslash = is_win and vim.opt.shellslash:get() or false

  return M.get_path(url, type)
    :next(function(directory)
      ts_grammar_dir = directory
      return M.exe(compiler, {
        args = compiler_args,
        cwd = directory,
      })
    end)
    :next(function(code)
      if code ~= 0 then
        error('[orgmode] Failed to compile parser', 0)
      end
      local move_cmd = M.select_mv_cmd('parser.so', M.get_parser_path(), ts_grammar_dir or '', is_win, shellslash)
      return M.exe(move_cmd.cmd, move_cmd.opts)
    end)
    :next(function(code)
      if code ~= 0 then
        error('[orgmode] Failed to move generated tree-sitter parser to runtime folder', 0)
      end
      return utils.writefile(lock_file, vim.json.encode({ version = required_version }))
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

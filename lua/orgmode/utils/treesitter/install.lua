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
    M.run('install')
    return true
  end

  -- Parser found but in invalid location
  if not version_info.install_location then
    M.run('install')
    M.notify_conflicting_parsers(version_info.conflicting_parsers)
    return true
  end

  if version_info.outdated then
    M.run('update')
    return true
  end

  if version_info.version_mismatch then
    M.reinstall()
    return true
  end

  M.notify_conflicting_parsers(version_info.conflicting_parsers)

  return false
end

function M.notify_conflicting_parsers(conflicting_parsers)
  if #conflicting_parsers > 0 then
    local list = vim.tbl_map(function(parser)
      return ('- `%s`'):format(parser)
    end, conflicting_parsers)
    utils.notify(
      ('Conflicting org parser(s) found in these locations:\n%s\nRemove them to avoid conflicts.'):format(
        table.concat(list, '\n')
      ),
      {
        level = 'warn',
        timeout = 5000,
      }
    )
  end
end

function M.reinstall()
  return M.run('reinstall')
end

function M.get_version_info()
  local result = {
    installed = false,
    correct_location = false,
    install_location = nil,
    installed_version = nil,
    outdated = false,
    required_version = required_version,
    version_mismatch = false,
    conflicting_parsers = {},
  }

  if M.not_installed() then
    return result
  end

  result.installed = true

  local parser_locations = M.get_parser_locations()
  result.conflicting_parsers = parser_locations.conflicting_parsers

  if not parser_locations.install_location then
    return result
  end

  result.install_location = parser_locations.install_location

  local installed_version = M.get_installed_version()
  result.installed_version = installed_version
  result.outdated = vim.version.lt(installed_version, required_version)
  result.version_mismatch = installed_version ~= required_version

  return result
end

function M.get_parser_locations()
  local installed_org_parsers = vim.api.nvim_get_runtime_file('parser/org.so', true)
  local parser_path = M.get_parser_path()
  local install_location = nil
  local conflicting_parsers = {}
  for _, parser in ipairs(installed_org_parsers) do
    if vim.fs.normalize(parser) == vim.fs.normalize(parser_path) then
      install_location = parser
    else
      table.insert(conflicting_parsers, parser)
    end
  end

  return {
    install_location = install_location,
    conflicting_parsers = conflicting_parsers,
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
function M.run(type)
  local url = 'https://github.com/nvim-orgmode/tree-sitter-org'
  local compiler = vim.tbl_filter(function(exe)
    return exe ~= vim.NIL and vim.fn.executable(exe) == 1
  end, M.compilers)[1]

  if not compiler then
    error('[orgmode] No C compiler found for installing tree-sitter grammar', 0)
  end

  local compiler_args = M.select_compiler_args(compiler)
  local path = nil

  return M.get_path(url, type)
    :next(function(directory)
      path = directory
      return M.exe(compiler, {
        args = compiler_args,
        cwd = directory,
      })
    end)
    :next(vim.schedule_wrap(function(code)
      if code ~= 0 then
        error('[orgmode] Failed to compile parser', 0)
      end
      local source = vim.fs.joinpath(path, 'parser.so')
      local destination = M.get_parser_path()
      local renamed = vim.fn.rename(source, destination)
      if renamed ~= 0 then
        error('[orgmode] Failed to move generated tree-sitter parser to runtime folder', 0)
      end
      utils.writefile(M.get_lock_file(), vim.json.encode({ version = required_version })):wait()
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

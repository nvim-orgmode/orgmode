local Promise = require('orgmode.utils.promise')
local utils = require('orgmode.utils')
local ts_revision = 'f8c6b1e72f82f17e41004e04e15f62a83ecc27b0'
local uv = vim.loop
local M = {
  compilers = { vim.fn.getenv('CC'), 'cc', 'gcc', 'clang', 'cl', 'zig' },
}

function M.get_package_path()
  -- Path to this source file, removing the leading '@'
  local source = string.sub(debug.getinfo(1, 'S').source, 2)

  -- Path to the package root
  return vim.fn.fnamemodify(source, ':p:h:h:h:h:h')
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

function M.get_path(url)
  local local_path = vim.fn.expand(url)
  local is_local_path = vim.fn.isdirectory(local_path) == 1

  if is_local_path then
    return Promise.resolve(local_path)
  end

  local path = ('%s/tree-sitter-org'):format(vim.fn.stdpath('cache'))
  vim.fn.delete(path, 'rf')

  utils.echo_info('Installing tree-sitter grammar...')
  return M.exe('git', {
    args = { 'clone', '--filter=blob:none', url, path },
  })
    :next(function(code)
      if code ~= 0 then
        error('[orgmode] Failed to clone tree-sitter-org', 0)
      end
      return M.exe('git', {
        args = { 'checkout', ts_revision },
        cwd = path,
      })
    end)
    :next(function(code)
      if code ~= 0 then
        error('[orgmode] Failed to checkout to correct revision on tree-sitter-org', 0)
      end
      return path
    end)
end

---@param url? string
function M.run(url)
  url = url or 'https://github.com/nvim-orgmode/tree-sitter-org'
  local compiler = vim.tbl_filter(function(exe)
    return exe ~= vim.NIL and vim.fn.executable(exe) == 1
  end, M.compilers)[1]

  if not compiler then
    error('[orgmode] No C compiler found for installing tree-sitter grammar', 0)
  end

  local compiler_args = M.select_compiler_args(compiler)
  local package_path = M.get_package_path()
  local path = nil

  return M.get_path(url)
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
      local renamed = vim.fn.rename(path .. '/parser.so', package_path .. '/parser/org.so')
      if renamed ~= 0 then
        error('[orgmode] Failed to move generated tree-sitter parser to runtime folder', 0)
      end
      utils.echo_info('Done!')
      return true
    end))
    :wait(60000)
end

return M

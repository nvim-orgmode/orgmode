local Promise = require('orgmode.utils.promise')
local uv = vim.loop
local M = {}

M.compilers = {}

M.compilers = { vim.fn.getenv('CC'), 'cc', 'gcc', 'clang', 'cl', 'zig' }
M.prefer_git = vim.fn.has('win32') == 1

function M.get_package_path()
  -- Path to this source file, removing the leading '@'
  local source = string.sub(debug.getinfo(1, 'S').source, 2)

  -- Path to the package root
  return vim.fn.fnamemodify(source, ':p:h:h:h:h:h')
end

function M.get_path_sep()
  return (vim.fn.has('win32') == 1 and not vim.opt.shellslash:get()) and '\\' or '/'
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

-- Convert path for cmd.exe on Windows.
-- This is needed when vim.opt.shellslash is in use.
---@param p string
---@return string
local function cmdpath(p)
  if vim.opt.shellslash:get() then
    local r = p:gsub('/', '\\')
    return r
  end
  return p
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

function M.select_mv_cmd(from, to, cwd)
  if vim.fn.has('win32') == 1 then
    return {
      cmd = 'cmd',
      opts = {
        args = { '/C', 'move', '/Y', cmdpath(from), cmdpath(to) },
        cwd = cwd,
      },
    }
  else
    return {
      cmd = 'mv',
      opts = {
        args = { '-f', from, to },
        cwd = cwd,
      },
    }
  end
end

---@param url string
function M.run(url)
  url = url or 'https://github.com/nvim-orgmode/tree-sitter-org'
  local compiler = vim.tbl_filter(function(exe)
    return exe ~= vim.NIL and vim.fn.executable(exe) == 1
  end, M.compilers)[1]

  if not compiler then
    error('[orgmode] No C compiler found for installing tree-sitter grammar')
  end

  local local_path = vim.fn.expand(url)
  local is_local_path = vim.fn.isdirectory(local_path) == 1
  -- if is_local_path then
  --   return M.exe(compiler, {
  --     args = M.select_compiler_args(compiler),
  --     cwd = local_path,
  --   }):next(function()
  --     return M.exe(M.select_mv_cmd(cmdpath(local_path .. '/parser.so'), M.get_package_path() .. '/parser/org.so'))
  --   end)
  -- end
  local path = url
  local compiler_args = M.select_compiler_args(compiler)
  local package_path = M.get_package_path()
  if not is_local_path then
    path = vim.fn.stdpath('cache') .. M.get_path_sep() .. 'tree-sitter-org'
    vim.fn.delete(path, 'rf')
    return M.exe('git', {
      args = { 'clone', '--filter=blob:none', url, path },
    })
      :next(function(code)
        if code ~= 0 then
          error('[orgmode] Failed to clone tree-sitter-org')
        end
        return M.exe('git', {
          args = { 'checkout', 'f8c6b1e72f82f17e41004e04e15f62a83ecc27b0' },
          cwd = path,
        })
      end)
      :next(function(code)
        if code ~= 0 then
          error('[orgmode] Failed to checkout to correct revision on tree-sitter-org')
        end
        return M.exe(compiler, {
          args = compiler_args,
          cwd = path,
        })
      end)
      :next(function(code)
        if code ~= 0 then
          error('[orgmode] Failed to compile parser')
        end
        return M.exe('rm', {
          args = { '-rf', package_path .. '/parser/org.so' },
        })
      end)
      :next(function()
        return M.exe('mv', {
          args = { path .. '/parser.so', package_path .. '/parser/org.so' },
        })
      end)
  end
end

return M

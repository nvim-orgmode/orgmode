local ts_install = require('orgmode.utils.treesitter.install')
local Promise = require('orgmode.utils.promise')
local uv = vim.uv

---@param path string
---@param content string
local function write_file(path, content)
  local file = assert(io.open(path, 'wb'))
  file:write(content)
  file:close()
end

---@param path string
---@return string
local function read_file(path)
  local file = assert(io.open(path, 'rb'))
  local content = file:read('*a')
  file:close()
  return content
end

describe('treesitter install', function()
  local tmp_root
  local parser_dir
  local src_dir
  local backup_dir

  before_each(function()
    tmp_root = vim.fn.tempname()
    parser_dir = vim.fs.joinpath(tmp_root, 'parser')
    src_dir = vim.fs.joinpath(tmp_root, 'src')
    backup_dir = vim.fs.joinpath(tmp_root, 'cache-backups')
    vim.fn.mkdir(parser_dir, 'p')
    vim.fn.mkdir(src_dir, 'p')
  end)

  after_each(function()
    vim.fn.delete(tmp_root, 'rf')
  end)

  describe('select_mv_cmd', function()
    it('normalizes forward slashes on Windows regardless of shellslash', function()
      local cmd = ts_install.select_mv_cmd('parser.so', 'C:/Users/test/parser/org.so', 'C:/cache/ts', true, false)
      assert.are.same({
        cmd = 'cmd',
        opts = {
          args = { '/C', 'move', '/Y', 'parser.so', 'C:\\Users\\test\\parser\\org.so' },
          cwd = 'C:/cache/ts',
        },
      }, cmd)
    end)

    it('uses mv -f on non-Windows platforms', function()
      local cmd = ts_install.select_mv_cmd('parser.so', '/tmp/parser/org.so', '/tmp/ts', false, false)
      assert.are.same({
        cmd = 'mv',
        opts = {
          args = { '-f', 'parser.so', '/tmp/parser/org.so' },
          cwd = '/tmp/ts',
        },
      }, cmd)
    end)
  end)

  describe('move_parser on Windows', function()
    local original_exe

    before_each(function()
      original_exe = ts_install.exe
    end)

    after_each(function()
      ts_install.exe = original_exe
    end)

    it('moves existing parser out of the way before placing the new parser', function()
      local target = vim.fs.joinpath(parser_dir, 'org.so')
      local source = vim.fs.joinpath(src_dir, 'parser.so')
      write_file(target, 'old-parser')
      write_file(source, 'new-parser')

      local target_existed_during_move = nil
      ts_install.exe = function()
        target_existed_during_move = uv.fs_stat(target) ~= nil
        assert(uv.fs_rename(source, target))
        return Promise.resolve(0, '')
      end

      local code, err = ts_install.move_parser('parser.so', target, src_dir, true, false, backup_dir):wait()
      assert.are.same(0, code)
      assert.are.same('', err)
      assert.is_false(target_existed_during_move)
      assert.are.same('new-parser', read_file(target))
    end)

    it('restores the previous parser if moving the new parser fails', function()
      local target = vim.fs.joinpath(parser_dir, 'org.so')
      write_file(target, 'old-parser')

      local target_existed_during_move = nil
      ts_install.exe = function()
        target_existed_during_move = uv.fs_stat(target) ~= nil
        return Promise.resolve(1, 'Access is denied.')
      end

      local code, err = ts_install.move_parser('parser.so', target, src_dir, true, false, backup_dir):wait()
      assert.are.same(1, code)
      assert.are.same('Access is denied.', err)
      assert.is_false(target_existed_during_move)
      assert.are.same('old-parser', read_file(target))
    end)

    it('falls back to renaming next to target when backup_dir cannot be used', function()
      local target = vim.fs.joinpath(parser_dir, 'org.so')
      local source = vim.fs.joinpath(src_dir, 'parser.so')
      local blocking_file = vim.fs.joinpath(tmp_root, 'not-a-directory')
      write_file(target, 'old-parser')
      write_file(source, 'new-parser')
      write_file(blocking_file, 'blocker')

      local backup_found_in_parser_dir = false
      ts_install.exe = function()
        assert.is_nil(uv.fs_stat(target))
        for name in vim.fs.dir(parser_dir) do
          if vim.startswith(name, 'org.so.') and vim.endswith(name, '.old') then
            backup_found_in_parser_dir = true
          end
        end
        assert(uv.fs_rename(source, target))
        return Promise.resolve(0, '')
      end

      local code = ts_install.move_parser('parser.so', target, src_dir, true, false, blocking_file):wait()
      assert.are.same(0, code)
      assert.is_true(backup_found_in_parser_dir)
      assert.are.same('new-parser', read_file(target))
    end)

    it('creates backup_dir safely inside a fast event loop callback', function()
      local target = vim.fs.joinpath(parser_dir, 'org.so')
      local source = vim.fs.joinpath(src_dir, 'parser.so')
      local nested_backup_dir = vim.fs.joinpath(backup_dir, 'nested', 'dir')
      write_file(target, 'old-parser')
      write_file(source, 'new-parser')

      local backup_created_in_nested_dir = false
      ts_install.exe = function()
        assert.is_nil(uv.fs_stat(target))
        for name in vim.fs.dir(nested_backup_dir) do
          if vim.startswith(name, 'org.so.') and vim.endswith(name, '.old') then
            backup_created_in_nested_dir = true
          end
        end
        assert(uv.fs_rename(source, target))
        return Promise.resolve(0, '')
      end

      local cmd = vim.fn.has('win32') == 1 and { 'cmd', '/C', 'echo', 'ok' } or { 'true' }
      local code = Promise.new(function(resolve)
        vim.system(cmd, {}, function()
          resolve(true)
        end)
      end)
        :next(function()
          return ts_install.move_parser('parser.so', target, src_dir, true, false, nested_backup_dir)
        end)
        :wait()

      assert.are.same(0, code)
      assert.is_true(backup_created_in_nested_dir)
      assert.are.same('new-parser', read_file(target))
    end)
  end)

  describe('cleanup_old_parsers', function()
    it('removes leftover .old parser backups while keeping active parser and unrelated files', function()
      vim.fn.mkdir(backup_dir, 'p')
      local target = vim.fs.joinpath(parser_dir, 'org.so')
      local parser_old = vim.fs.joinpath(parser_dir, 'org.so.123.456.old')
      local unrelated_parser_file = vim.fs.joinpath(parser_dir, 'other.so')
      local cache_old = vim.fs.joinpath(backup_dir, 'org.so.789.012.old')

      write_file(target, 'active')
      write_file(parser_old, 'stale-local')
      write_file(unrelated_parser_file, 'other')
      write_file(cache_old, 'stale-cache')

      ts_install.cleanup_old_parsers(target, backup_dir)

      assert.is_not_nil(uv.fs_stat(target))
      assert.is_not_nil(uv.fs_stat(unrelated_parser_file))
      assert.is_nil(uv.fs_stat(parser_old))
      assert.is_nil(uv.fs_stat(cache_old))
    end)
  end)
end)

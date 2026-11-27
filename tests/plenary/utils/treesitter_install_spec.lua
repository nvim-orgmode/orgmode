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

  before_each(function()
    tmp_root = vim.fn.tempname()
    parser_dir = vim.fs.joinpath(tmp_root, 'parser')
    src_dir = vim.fs.joinpath(tmp_root, 'src')
    vim.fn.mkdir(parser_dir, 'p')
    vim.fn.mkdir(src_dir, 'p')
  end)

  after_each(function()
    vim.fn.delete(tmp_root, 'rf')
  end)

  describe('select_mv_cmd', function()
    it('normalizes forward slashes on Windows when shellslash is set', function()
      local cmd = ts_install.select_mv_cmd('parser.so', 'C:/Users/test/parser/org.so', 'C:/cache/ts', true, true)
      assert.are.same({
        cmd = 'cmd',
        opts = {
          args = { '/C', 'move', '/Y', 'parser.so', 'C:\\Users\\test\\parser\\org.so' },
          cwd = 'C:/cache/ts',
        },
      }, cmd)
    end)

    it('leaves paths unchanged on Windows when shellslash is false', function()
      local cmd = ts_install.select_mv_cmd('parser.so', 'C:/Users/test/parser/org.so', 'C:/cache/ts', true, false)
      assert.are.same({
        cmd = 'cmd',
        opts = {
          args = { '/C', 'move', '/Y', 'parser.so', 'C:/Users/test/parser/org.so' },
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

      local code, err = ts_install.move_parser('parser.so', target, src_dir, true, false):wait()
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

      local code, err = ts_install.move_parser('parser.so', target, src_dir, true, false):wait()
      assert.are.same(1, code)
      assert.are.same('Access is denied.', err)
      assert.is_false(target_existed_during_move)
      assert.are.same('old-parser', read_file(target))
    end)

    it('includes restore error message if restoring the backup fails', function()
      local target = vim.fs.joinpath(parser_dir, 'org.so')
      write_file(target, 'old-parser')

      local original_rename = uv.fs_rename
      ts_install.exe = function()
        return Promise.resolve(1, 'Access is denied.')
      end

      -- Stub rename during restore so it fails
      local rename_calls = 0
      uv.fs_rename = function(src, dst)
        rename_calls = rename_calls + 1
        if rename_calls == 1 then
          return original_rename(src, dst)
        end
        return nil, 'restore permission denied'
      end

      local status, code, err = pcall(function()
        return ts_install.move_parser('parser.so', target, src_dir, true, false):wait()
      end)
      uv.fs_rename = original_rename

      assert.is_true(status)
      assert.are.same(1, code)
      assert.is_true(err:find('Failed to restore parser backup', 1, true) ~= nil)
      assert.is_true(err:find('restore permission denied', 1, true) ~= nil)
    end)
  end)

  describe('cleanup_old_parsers', function()
    it('removes leftover .old parser backups while keeping active parser and unrelated files', function()
      local target = vim.fs.joinpath(parser_dir, 'org.so')
      local parser_old = vim.fs.joinpath(parser_dir, 'org.so.123.456.old')
      local unrelated_parser_file = vim.fs.joinpath(parser_dir, 'other.so')

      write_file(target, 'active')
      write_file(parser_old, 'stale-local')
      write_file(unrelated_parser_file, 'other')

      ts_install.cleanup_old_parsers(target)

      assert.is_not_nil(uv.fs_stat(target))
      assert.is_not_nil(uv.fs_stat(unrelated_parser_file))
      assert.is_nil(uv.fs_stat(parser_old))
    end)
  end)
end)

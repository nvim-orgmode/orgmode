local fs_utils = require('orgmode.utils.fs')
local helpers = require('tests.plenary.helpers')

local uv = vim.uv or vim.loop
local file = helpers.create_file({})

describe('get_current_file_dir', function()
  it('gives the dirname of current_file_path', function()
    assert.are.same(vim.fs.dirname(file.filename), fs_utils.get_current_file_dir())
  end)

  it('always gives an absolute path', function()
    local tempdir = vim.fs.dirname(file.filename)
    helpers.with_cwd(tempdir, function()
      assert.are.same('.', vim.fs.dirname(vim.fn.bufname()))
      local dir = fs_utils.get_current_file_dir()
      assert.are.same(dir .. '/', vim.fn.fnamemodify(dir, ':p'))
    end)
  end)
end)

describe('substitute_path', function()
  it('leaves absolute paths untouched', function()
    assert.are.same('/a/b/c', fs_utils.substitute_path('/a/b/c'))
  end)

  it('expands ~ to HOME', function()
    local output
    helpers.with_var(vim.env, 'HOME', '/home/org', function()
      output = fs_utils.substitute_path('~/foobar')
    end)
    assert.are.same('/home/org/foobar', output)
  end)

  it('expands . to the current file dir', function()
    local output = fs_utils.substitute_path('./a/b')
    assert(output)
    assert(vim.startswith(output, vim.fs.dirname(file.filename)))
  end)

  it('expands .. to the current file dir plus ..', function()
    local output = fs_utils.substitute_path('../a/b')
    assert(output)
    assert(vim.startswith(output, vim.fs.dirname(file.filename)))
    local normalized = vim.fs.normalize(output)
    assert.are.Not.same(output, normalized, "normalize didn't remove ..")
  end)

  it('fails on all other relative paths', function()
    assert.is.False(fs_utils.substitute_path('a/b/c'))
  end)
end)

describe('get_real_path', function()
  local link_name = nil

  before_each(function()
    if not link_name then
      link_name = vim.fn.tempname()
      assert(uv.fs_symlink(file.filename, link_name))
    end
  end)

  it('resolves symlinks', function()
    assert(link_name)
    assert.are.same(file.filename, fs_utils.get_real_path(link_name))
  end)

  it('resolves relative paths', function()
    assert(link_name)
    local relpath = vim.fs.joinpath('.', vim.fs.basename(link_name))
    assert.are.same(file.filename, fs_utils.get_real_path(relpath))
  end)

  it('keeps trailing slash if it is there', function()
    local path = fs_utils.get_real_path('././')
    assert.are.same(vim.fs.dirname(file.filename) .. '/', path)
  end)

  it('keeps trailing slash away if it is not there', function()
    local path = fs_utils.get_real_path('./.')
    assert.are.same(vim.fs.dirname(file.filename), path)
  end)

  it('fails on bare dot "."', function()
    assert.is.False(fs_utils.get_real_path('.'))
  end)
end)

describe('trim_common_root', function()
  it('trims the common root when all files share the same root with the shortest one', function()
    local result = fs_utils.trim_common_root({
      '/foo/bar/baz.org',
      '/foo/bar/baz/bar.org',
      '/foo/bar/baz3.org',
    })
    assert.are.same({
      'baz.org',
      'baz/bar.org',
      'baz3.org',
    }, result)
  end)

  it('trims the common root when there are multiple different roots', function()
    local result = fs_utils.trim_common_root({
      '/foo/bar/tea/notes.org',
      '/foo/bar/tea/todos.org',
      '/foo/bar/baz/work.org',
      '/foo/bar/baz/personal.org',
      '/foo/bar/baz/project.org',
    })

    assert.are.same({
      'tea/notes.org',
      'tea/todos.org',
      'baz/work.org',
      'baz/personal.org',
      'baz/project.org',
    }, result)
  end)

  it('returns paths as they are if they do not share the common root', function()
    local result = fs_utils.trim_common_root({
      '/foo/bar/tea/notes.org',
      '/foo/bar/tea/todos.org',
      '/foo/bar/baz/work.org',
      '/foo/bar/baz/personal.org',
      '/other/bar/baz/project.org',
    })

    assert.are.same({
      'foo/bar/tea/notes.org',
      'foo/bar/tea/todos.org',
      'foo/bar/baz/work.org',
      'foo/bar/baz/personal.org',
      'other/bar/baz/project.org',
    }, result)
  end)
end)

describe('make_relative', function()
  local path = fs_utils.get_real_path(file.filename) ---@cast path string
  local basename = vim.fs.basename(path)
  local dirname = vim.fs.dirname(path)
  local dirname_slash = vim.fs.joinpath(dirname, '')
  local root = path
  for parent in vim.fs.parents(path) do
    root = parent
  end

  it('gets the basename', function()
    local expected = vim.fs.joinpath('.', basename)
    local actual = fs_utils.make_relative(path, dirname)
    assert.are.same(expected, actual)
  end)

  it('gets the basename with trailing slash', function()
    local expected = vim.fs.joinpath('.', basename)
    local actual = fs_utils.make_relative(path, dirname_slash)
    assert.are.same(expected, actual)
  end)

  it('works one level up', function()
    local parent_name = vim.fs.basename(dirname)
    local expected = vim.fs.joinpath('.', parent_name, basename)
    local actual = fs_utils.make_relative(path, vim.fs.dirname(dirname))
    assert.are.same(expected, actual)
  end)

  it('works one level up with trailing slash', function()
    local parent_name = vim.fs.basename(dirname)
    local expected = vim.fs.joinpath('.', parent_name, basename)
    local actual = fs_utils.make_relative(path, vim.fs.dirname(dirname) .. '/')
    assert.are.same(expected, actual)
  end)

  it('produces a relative path even at the root', function()
    local relpath = fs_utils.make_relative(path, root)
    assert(vim.endswith(path, relpath))
  end)

  it('climbs up via ..', function()
    local relpath = fs_utils.make_relative(root, path)
    local only_cdup = vim.regex('\\V\\(../\\)\\+')
    assert(only_cdup:match_str(relpath))
  end)
end)

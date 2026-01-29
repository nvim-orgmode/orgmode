local helpers = require('tests.plenary.helpers')

local function stat_mode(path)
  local st = vim.uv.fs_stat(path)
  assert.is_not_nil(st)
  -- libuv returns st.mode containing type bits + permission bits
  return bit.band(st.mode, 0x1FF)
end

describe('Tangle (shebang & mode)', function()
  it('should prepend shebang and default to 0755 when :shebang is set', function()
    local file = helpers.create_file({
      '#+property: header-args :tangle yes',
      '* Headline',
      "#+begin_src sh :shebang '#!/usr/bin/env bash'",
      'echo "hi"',
      '#+end_src',
    })

    vim.cmd('norm ,obt')

    local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.sh'
    assert.is.Not.Nil(vim.uv.fs_stat(tangled_file))
    assert.are.same({
      '#!/usr/bin/env bash',
      'echo "hi"',
    }, vim.fn.readfile(tangled_file))

    assert.are.equal(tonumber("0755", 8), stat_mode(tangled_file))
  end)

  it('should apply :tangle-mode octal form (o644) when provided', function()
    local file = helpers.create_file({
      '#+property: header-args :tangle yes',
      '* Headline',
      "#+begin_src lua :tangle-mode 'o644'",
      'print("hi")',
      '#+end_src',
    })

    vim.cmd('norm ,obt')

    local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
    assert.is.Not.Nil(vim.uv.fs_stat(tangled_file))
    assert.are.equal(tonumber("0644", 8), stat_mode(tangled_file))
  end)

  it('should apply :tangle-mode chmod style (u=rw,go=r) when provided', function()
    local file = helpers.create_file({
      '#+property: header-args :tangle yes',
      '* Headline',
      "#+begin_src lua :tangle-mode 'u=rw,go=r'",
      'print("hi")',
      '#+end_src',
    })

    vim.cmd('norm ,obt')

    local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
    assert.is.Not.Nil(vim.uv.fs_stat(tangled_file))
    assert.are.equal(tonumber("0644", 8), stat_mode(tangled_file))
  end)

  it('should apply :tangle-mode ls style (rwxr-x---) when provided', function()
    local file = helpers.create_file({
      '#+property: header-args :tangle yes',
      '* Headline',
      "#+begin_src lua :tangle-mode 'rwxr-x---'",
      'print("hi")',
      '#+end_src',
    })

    vim.cmd('norm ,obt')

    local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
    assert.is.Not.Nil(vim.uv.fs_stat(tangled_file))
    assert.are.equal(tonumber("0750", 8), stat_mode(tangled_file))
  end)

  it('should keep 0755 when :shebang is set even if :tangle-mode is also set (mode is overridden if :tangle-mode present)', function()
    local file = helpers.create_file({
      '#+property: header-args :tangle yes',
      '* Headline',
      "#+begin_src sh :shebang '#!/usr/bin/env bash' :tangle-mode 'o700'",
      'echo "hi"',
      '#+end_src',
    })

    vim.cmd('norm ,obt')

    local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.sh'
    assert.is.Not.Nil(vim.uv.fs_stat(tangled_file))

    assert.are.same({
      '#!/usr/bin/env bash',
      'echo "hi"',
    }, vim.fn.readfile(tangled_file))

    -- :tangle-mode should override the shebang default
    assert.are.equal(tonumber("0700", 8), stat_mode(tangled_file))
  end)
end)

local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')

describe('Tangle', function()
  describe('with header args', function()
    it('should not tangle a file with default settings', function()
      local file = helpers.create_file({
        '#+begin_src lua',
        'print("test first line")',
        'print("test first second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')
      local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
      assert.is.Nil(vim.loop.fs_stat(tangled_file))
    end)

    it('should tangle a file when enabled in config', function()
      config:extend({
        org_babel_default_header_args = {
          [':tangle'] = 'yes',
          [':noweb'] = 'no',
        },
      })
      local file = helpers.create_file({
        '#+begin_src lua',
        'print("test first line")',
        'print("test first second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')
      local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
      assert.is.Not.Nil(vim.loop.fs_stat(tangled_file))
      assert.are.same({
        'print("test first line")',
        'print("test first second line")',
      }, vim.fn.readfile(tangled_file))
      config:extend({
        org_babel_default_header_args = {
          [':tangle'] = 'no',
          [':noweb'] = 'no',
        },
      })
    end)

    it('should tangle a file when enabled in file properties', function()
      local file = helpers.create_file({
        '#+property: header-args :tangle yes :noweb no',
        '* Headline',
        '#+begin_src lua',
        'print("test first line")',
        'print("test first second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')
      local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
      assert.is.Not.Nil(vim.loop.fs_stat(tangled_file))
      assert.are.same({
        'print("test first line")',
        'print("test first second line")',
      }, vim.fn.readfile(tangled_file))
    end)

    it('should tangle a file when enabled in headline properties', function()
      local file = helpers.create_file({
        '* Headline',
        ':PROPERTIES:',
        ':header-args: :tangle yes',
        ':END:',
        '#+begin_src lua',
        'print("test first line")',
        'print("test first second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')
      local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
      assert.is.Not.Nil(vim.loop.fs_stat(tangled_file))
      assert.are.same({
        'print("test first line")',
        'print("test first second line")',
      }, vim.fn.readfile(tangled_file))
    end)

    it('should tangle a file when enabled in block args', function()
      local file = helpers.create_file({
        '* Headline',
        '#+begin_src lua :tangle yes',
        'print("test first line")',
        'print("test first second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')
      local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
      assert.is.Not.Nil(vim.loop.fs_stat(tangled_file))
      assert.are.same({
        'print("test first line")',
        'print("test first second line")',
      }, vim.fn.readfile(tangled_file))
    end)

    it('should not tangle a file when enabled in file properties but disabled in block args', function()
      local file = helpers.create_file({
        '#+property: header-args :tangle yes :noweb no',
        '* Headline',
        '#+begin_src lua :tangle no',
        'print("test first line")',
        'print("test first second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')
      local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
      assert.is.Nil(vim.loop.fs_stat(tangled_file))
    end)
  end)

  describe('When tangle is "yes"', function()
    it('should tangle all blocks of same filetype in same file', function()
      local file = helpers.create_file({
        '#+property: header-args :tangle yes',
        '* Headline',
        '#+begin_src lua',
        'print("Headline first line")',
        'print("Headline second line")',
        '#+end_src',
        '* Other headline',
        '#+begin_src lua',
        'print("Other headline first line")',
        'print("Other headline second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')

      local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
      assert.is.Not.Nil(vim.loop.fs_stat(tangled_file))
      assert.are.same({
        'print("Headline first line")',
        'print("Headline second line")',
        '',
        'print("Other headline first line")',
        'print("Other headline second line")',
      }, vim.fn.readfile(tangled_file))
    end)

    it('should tangle only blocks that have tangle yes', function()
      local file = helpers.create_file({
        '#+property: header-args :tangle yes',
        '* Headline',
        '#+begin_src lua :tangle no',
        'print("Headline first line")',
        'print("Headline second line")',
        '#+end_src',
        '* Other headline',
        '#+begin_src lua',
        'print("Other headline first line")',
        'print("Other headline second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')

      local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
      assert.is.Not.Nil(vim.loop.fs_stat(tangled_file))
      assert.are.same({
        'print("Other headline first line")',
        'print("Other headline second line")',
      }, vim.fn.readfile(tangled_file))
    end)
  end)

  describe('When tangle is specific file', function()
    it('should tangle all blocks to the same file with absolute path', function()
      local abs_path = vim.fn.tempname() .. '.notlua'
      helpers.create_file({
        '#+property: header-args :tangle ' .. abs_path,
        '* Headline',
        '#+begin_src lua',
        'print("Headline first line")',
        'print("Headline second line")',
        '#+end_src',
        '* Other headline',
        '#+begin_src lua',
        'print("Other headline first line")',
        'print("Other headline second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')

      assert.is.Not.Nil(vim.loop.fs_stat(abs_path))
      assert.are.same({
        'print("Headline first line")',
        'print("Headline second line")',
        '',
        'print("Other headline first line")',
        'print("Other headline second line")',
      }, vim.fn.readfile(abs_path))
    end)

    it('should tangle all blocks to the same file with relative path prefixed with ./', function()
      local abs_path = vim.fn.tempname() .. '.notlua'
      local rel_path = './' .. vim.fn.fnamemodify(abs_path, ':t')
      helpers.create_file({
        '#+property: header-args :tangle ' .. rel_path,
        '* Headline',
        '#+begin_src lua',
        'print("Headline first line")',
        'print("Headline second line")',
        '#+end_src',
        '* Other headline',
        '#+begin_src lua',
        'print("Other headline first line")',
        'print("Other headline second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')

      assert.is.Not.Nil(vim.loop.fs_stat(abs_path))
      assert.are.same({
        'print("Headline first line")',
        'print("Headline second line")',
        '',
        'print("Other headline first line")',
        'print("Other headline second line")',
      }, vim.fn.readfile(abs_path))
    end)

    it('should tangle all blocks to the same file with relative path without prefix', function()
      local abs_path = vim.fn.tempname() .. '.notlua'
      local rel_path = vim.fn.fnamemodify(abs_path, ':t')
      helpers.create_file({
        '#+property: header-args :tangle ' .. rel_path,
        '* Headline',
        '#+begin_src lua',
        'print("Headline first line")',
        'print("Headline second line")',
        '#+end_src',
        '* Other headline',
        '#+begin_src lua',
        'print("Other headline first line")',
        'print("Other headline second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')

      assert.is.Not.Nil(vim.loop.fs_stat(abs_path))
      assert.are.same({
        'print("Headline first line")',
        'print("Headline second line")',
        '',
        'print("Other headline first line")',
        'print("Other headline second line")',
      }, vim.fn.readfile(abs_path))
    end)

    it('should tangle blocks to different files', function()
      local abs_path = vim.fn.tempname() .. '.notlua'
      local single_block_abs_path = vim.fn.tempname() .. '.lua'
      local rel_path = vim.fn.fnamemodify(abs_path, ':t')
      helpers.create_file({
        '#+property: header-args :tangle ' .. rel_path,
        '* Headline',
        '#+begin_src lua',
        'print("Headline first line")',
        'print("Headline second line")',
        '#+end_src',
        '* Other headline',
        '#+begin_src lua :tangle ' .. single_block_abs_path,
        'print("Other headline first line")',
        'print("Other headline second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')

      assert.is.Not.Nil(vim.loop.fs_stat(abs_path))
      assert.is.Not.Nil(vim.loop.fs_stat(single_block_abs_path))
      assert.are.same({
        'print("Headline first line")',
        'print("Headline second line")',
      }, vim.fn.readfile(abs_path))
      assert.are.same({
        'print("Other headline first line")',
        'print("Other headline second line")',
      }, vim.fn.readfile(single_block_abs_path))
    end)
  end)

  describe('Noweb', function()
    it('should tangle all blocks and reference another block via noweb', function()
      local file = helpers.create_file({
        '#+property: header-args :tangle yes :noweb yes',
        '* Headline',
        '#+begin_src lua',
        '<<otherblock>>',
        'print("Headline first line")',
        'print("Headline second line")',
        '#+end_src',
        '* Other headline',
        '#+name: otherblock',
        '#+begin_src lua',
        'print("Other headline first line")',
        'print("Other headline second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')

      local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
      assert.is.Not.Nil(vim.loop.fs_stat(tangled_file))
      assert.are.same({
        'print("Other headline first line")',
        'print("Other headline second line")',
        'print("Headline first line")',
        'print("Headline second line")',
        '',
        'print("Other headline first line")',
        'print("Other headline second line")',
      }, vim.fn.readfile(tangled_file))
    end)

    it('should tangle only selected blocks and reference another block via noweb', function()
      local file = helpers.create_file({
        '#+property: header-args :tangle yes :noweb yes',
        '* Headline',
        '#+begin_src lua',
        '<<otherblock>>',
        'print("Headline first line")',
        'print("Headline second line")',
        '#+end_src',
        '* Other headline',
        '#+name: otherblock',
        '#+begin_src lua :tangle no',
        'print("Other headline first line")',
        'print("Other headline second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')

      local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
      assert.is.Not.Nil(vim.loop.fs_stat(tangled_file))
      assert.are.same({
        'print("Other headline first line")',
        'print("Other headline second line")',
        'print("Headline first line")',
        'print("Headline second line")',
      }, vim.fn.readfile(tangled_file))
    end)

    it('should tangle all blocks and not reference another block via noweb if disabled', function()
      local file = helpers.create_file({
        '#+property: header-args :tangle yes :noweb yes',
        '* Headline',
        '#+begin_src lua :noweb no',
        '<<otherblock>>',
        'print("Headline first line")',
        'print("Headline second line")',
        '#+end_src',
        '* Other headline',
        '#+name: otherblock',
        '#+begin_src lua :tangle yes',
        'print("Other headline first line")',
        'print("Other headline second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')

      local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
      assert.is.Not.Nil(vim.loop.fs_stat(tangled_file))
      assert.are.same({
        '<<otherblock>>',
        'print("Headline first line")',
        'print("Headline second line")',
        '',
        'print("Other headline first line")',
        'print("Other headline second line")',
      }, vim.fn.readfile(tangled_file))
    end)

    it('should tangle all blocks and reference another block via noweb if value is "tangle"', function()
      local file = helpers.create_file({
        '#+property: header-args :tangle yes',
        '* Headline',
        '#+begin_src lua :noweb tangle',
        '<<otherblock>>',
        'print("Headline first line")',
        'print("Headline second line")',
        '#+end_src',
        '* Other headline',
        '#+name: otherblock',
        '#+begin_src lua :tangle yes',
        'print("Other headline first line")',
        'print("Other headline second line")',
        '#+end_src',
      })
      vim.cmd('norm ,obt')

      local tangled_file = vim.fn.fnamemodify(file.filename, ':r') .. '.lua'
      assert.is.Not.Nil(vim.loop.fs_stat(tangled_file))
      assert.are.same({
        'print("Other headline first line")',
        'print("Other headline second line")',
        'print("Headline first line")',
        'print("Headline second line")',
        '',
        'print("Other headline first line")',
        'print("Other headline second line")',
      }, vim.fn.readfile(tangled_file))
    end)
  end)
end)

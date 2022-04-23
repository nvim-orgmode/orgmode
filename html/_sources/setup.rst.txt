Setup
============


.. code-block:: lua

    -- init.lua

    -- Load custom tree-sitter grammar for org filetype
    require('orgmode').setup_ts_grammar()

    -- Tree-sitter configuration
    require'nvim-treesitter.configs'.setup {
      -- If TS highlights are not enabled at all, or disabled via ``disable`` prop, highlighting will fallback to default Vim syntax highlighting
      highlight = {
        enable = true,
        disable = {'org'}, -- Remove this to use TS highlighter for some of the highlights (Experimental)
        additional_vim_regex_highlighting = {'org'}, -- Required since TS highlighter doesn't support all syntax features (conceal)
      },
      ensure_installed = {'org'}, -- Or run :TSUpdate org
    }

    require('orgmode').setup({
      org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
      org_default_notes_file = '~/Dropbox/org/refile.org',
    })

Or if you are using ``init.vim``:

.. code-block:: vim

    " init.vim
    lua << EOF

    -- Load custom tree-sitter grammar for org filetype
    require('orgmode').setup_ts_grammar()

    -- Tree-sitter configuration
    require'nvim-treesitter.configs'.setup {
      -- If TS highlights are not enabled at all, or disabled via `disable` prop, highlighting will fallback to default Vim syntax highlighting
      highlight = {
        enable = true,
        disable = {'org'}, -- Remove this to use TS highlighter for some of the highlights (Experimental)
        additional_vim_regex_highlighting = {'org'}, -- Required since TS highlighter doesn't support all syntax features (conceal)
      },
      ensure_installed = {'org'}, -- Or run :TSUpdate org
    }

    require('orgmode').setup({
      org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
      org_default_notes_file = '~/Dropbox/org/refile.org',
    })
    EOF

* **Open agenda prompt**: ``<Leader>oa``
* **Open capture prompt**: ``<Leader>oc``
* In any orgmode buffer press ``g?`` for help

If you are new to Orgmode, see `Getting started </DOCS.md#getting-started-with-orgmode>`_ section in Docs.

Completion
************

If you use `nvim-compe <https://github.com/hrsh7th/nvim-compe>`_ and want
to enable autocompletion, add this to your compe config:


.. code-block:: lua

    require'compe'.setup({
      source = {
        orgmode = true
      }
    })

For `nvim-cmp <https://github.com/hrsh7th/nvim-cmp>`_, add ``orgmode`` to list of sources:

.. code-block:: lua

    require'cmp'.setup({
      sources = {
        { name = 'orgmode' }
      }
    })

For `completion.nvim <https://github.com/nvim-lua/completion-nvim>`_, just add ``omni`` mode to chain complete list and add additional keyword chars:

.. code-block:: lua

    vim.g.completion_chain_complete_list = {
      org = {
        { mode = 'omni'},
      },
    }
    vim.cmd[[autocmd FileType org setlocal iskeyword+=:,#,+]]

Or just use ``omnifunc`` via ``<C-x><C-o>``

Tree-sitter info
****************
Built in tree-sitter parser is used for parsing the org files.
Highlights are experimental and partially supported.

Advantages of tree-sitter over built in parsing/syntax:
############################################################
* More reliable, since parsing is done with proper parsing tool
* Better highlighting (Experimental, still requires improvements)
* Future features will be easier to implement because grammar already parses some things that were not parsed before (tables, latex, etc.)
* Allows for easier hacking (custom motions that can work with TS nodes, etc.)

Known highlighting issues and limitations
################################################
* Performance issues. This is generally an issue in Neovim that should be resolved before 0.6 release (`neovim Issue #14762 <https://github.com/neovim/neovim/issues/14762>`_, `neovim Issue #14762 <https://github.com/neovim/neovim/issues/14762>`_)
* Anything that requires concealing (`org_hide_emphasis_markers </DOCS.md#org_hide_emphasis_markers>`_, links concealing) is not (yet) supported in TS highlighter
* LaTex is still highlighted through syntax file

Improvements over Vim's syntax highlighting
################################################
* Better highlighting of certain parts (tags, deadline/schedule/closed dates)
* `Tree-sitter highlight injections <https://github.com/nvim-treesitter/nvim-treesitter/blob/4f2265632becabcd2c5b1791fa31ef278f1e496c/CONTRIBUTING.md#injections>`_ through ``#BEGIN_SRC filetype`` blocks
* Headline markup highlighting (`Issue #67 <https://github.com/nvim-orgmode/orgmode/issues/67>`_)

Troubleshoot
############

- **Folding is not working**

Make sure you are not overriding foldexpr in Org buffers with `nvim-treesitter folding <https://github.com/nvim-treesitter/nvim-treesitter#folding>`_

- **Indentation is not working**

Make sure you are not overriding indentexpr in Org buffers with `nvim-treesitter indentation <https://github.com/nvim-treesitter/nvim-treesitter#indentation>`_

- **I get** ``treesitter/query.lua`` **errors when opening agenda/capture prompt or org files**

Make sure you are using latest changes from `tree-sitter-org <https://github.com/milisims/tree-sitter-org>`_ grammar by running ``:TSUpdate org`` and restarting the editor.

- **Dates are not in English**

Dates are generated with Lua native date support, and it reads your current locale when creating them.

To use different locale you can add this to your ``init.lua``:

.. code-block:: lua

    vim.cmd('language en_US.utf8')

or ``init.vim``:


.. code-block:: vim

    language en_US.utf8

Just make sure you have ``en_US`` locale installed on your system. To see what you have available on the system you can
start the command ``:language`` and press ``<TAB>`` to autocomplete possible options.

- **Links are not concealed**

Links are concealed with Vim's conceal feature (see ``:help conceal``). To enable concealing, add this to your ``init.lua``:

.. code-block:: lua

    vim.opt.conceallevel = 2
    vim.opt.concealcursor = 'nc'

Or if you are using ``init.vim``:


.. code-block:: vim

    set conceallevel=2
    set concealcursor=nc


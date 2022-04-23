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

Gifs
************
Agenda
############

.. raw:: html

  <img alt="agenda" src="https://user-images.githubusercontent.com/1782860/123549968-8521f600-d76b-11eb-9a93-02bad08b37ce.gif" />

Org file
############

.. raw:: html

  <img alt="orgfile" src="https://user-images.githubusercontent.com/1782860/123549982-90752180-d76b-11eb-8828-9edf9f76af08.gif" />

Capturing and refiling
########################

.. raw:: html

  <img alt="capture" src="https://user-images.githubusercontent.com/1782860/123549993-9a972000-d76b-11eb-814b-b348a93df08a.gif" />

Autocompletion
##############

.. raw:: html

  <img alt="autocomplete" src="https://user-images.githubusercontent.com/1782860/123550227-e8605800-d76c-11eb-96f6-c0a677d562d4.gif" />

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

Features (TL;DR):
*****************
* Agenda view
* Search by tags/keyword
* Clocking time
* Repeatable dates, date and time ranges
* Capturing to default notes file/destination
* Archiving (archive file or ARCHIVE tag)
* Exporting (via ``emacs``, ``pandoc`` and custom export options)
* Notifications (experimental, see `Issue #49 <https://github.com/nvim-orgmode/orgmode/issues/49>`_)
* Calendar popup for easier navigation and date updates
* Various org file mappings:

  * Promote/Demote
  * Change TODO state
  * Change dates
  * Insert/Move/Refile headlines
  * Change tags
  * Toggle checkbox state

* Clocking time
* Remote editing from agenda view
* Repeatable mapping via `vim-repeat <https://github.com/tpope/vim-repeat>`_

Features (Detailed breakdown):
******************************
* Agenda prompt:

  * Agenda view (``a``):

    * Ability to show daily(``vd``)/weekly(``vw``)/monthly(``vm``)/yearly(``vy``) agenda
    * Support for various date settings:

      * DEADLINE:  Warning settings - example:  `<2021-06-11 Fri 11:00 -1d>`
      * SCHEDULED: Delay setting - example: `<2021-06-11 Fri 11:00 -2d>`
      * All dates - Repeater settings:

        * Cumulate type: `<2021-06-11 Fri 11:00 +1w>`
        * Catch-up type: `<2021-06-11 Fri 11:00 ++1w>`
        * Restart type: `<2021-06-11 Fri 11:00 .+1w>`

      * Time ranges - example: `<2021-06-11 Fri 11:00-12:30>`
      * Date ranges - example: `<2021-06-11 Fri 11:00-12:30>--<2021-06-13 Sun 22:00>`

    * Properly lists tasks according to defined dates (DEADLINE,SCHEDULED,Plain date)
    * Navigate forward (``f``)/backward(``b``) or jump to specific date (``J``)
    * Go to task under cursor in current window(``<CR>``) or other window(``<TAB>``)
    * Print category from ":CATEGORY:" property if defined

  * List tasks that have "TODO" state (``t``):
  * Find headlines matching tag(s) (``m``):
  * Search for headlines (and it's content) for a query (``s``):
  * `Advanced search <DOCS.md#advanced-search>`_ for tags/todo kewords/properties
  * Notifications (experimental, see `Issue #49 <https://github.com/nvim-orgmode/orgmode/issues/49>`_)
  * Clocking time

* Capture:

  * Define custom templates
  * Fast capturing to default notes file via ``<C-c>``
  * Capturing to specific destination ``<Leader>or``
  * Abort capture with ``<Leader>ok``

* Org files

  * Clocking time
  * Refile to destination/headline: ``<Leader>or``
  * Increase/Decrease date under cursor: ``<C-a>``/``<C-x>``
  * Change date under cursor via calendar popup: ``cid``
  * Change headline TODO state: forward``cit`` or backward``ciT``
  * Open hyperlink or date under cursor: ``<Leader>oo``
  * Toggle checkbox: ``<C-space>``
  * Toggle current line to headline and vice versa: ``<Leader>o*``
  * Toggle folding of current headline: ``<TAB>``
  * Toggle folding in whole file: ``<S-TAB>``
  * Archive headline: ``<Leader>o$``
  * Add archive tag: ``<Leader>oA``
  * Change tags: ``<Leader>ot``
  * Promote headline: ``<<``
  * Demote headline: ``>>``
  * Promote subtree: ``<s``
  * Demote subtree: ``>s``
  * Add headline/list item/checkbox: ``<Leader><CR>``
  * Insert heading after current heading and it's content: ``<Leader>oih``
  * Insert TODO heading after current line: ``<Leader>oiT``
  * Insert TODO heading after current heading and it's content: ``<Leader>oit``
  * Move headline up: ``<Leader>oK``
  * Move headline down: ``<Leader>oJ``
  * Highlighted code blocks (`#+BEGIN_SRC filetype`)
  * Exporting (via ``emacs``, ``pandoc`` and custom export options)

Link to detailed documentation: `DOCS <DOCS.md>`_


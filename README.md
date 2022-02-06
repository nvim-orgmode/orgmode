

<div align="center">
  <img alt="[org-neovim-blend" src="https://user-images.githubusercontent.com/1782860/124820564-eddc5000-df6d-11eb-9016-d0c073a9575c.png" width="250" />

  # Orgmode.nvim


  <a href="/LICENSE">![License](https://img.shields.io/badge/license-MIT-brightgreen?style=flat-square)</a><a href="https://ko-fi.com/kristijanhusak"> ![Kofi](https://img.shields.io/badge/support-kofi-00b9fe?style=flat-square&logo=kofi)</a>

  Orgmode clone written in Lua for Neovim 0.5.

  [Installation](#installation) | [Setup](#setup) | [Troubleshoot](#troubleshoot) |  [Gifs](#gifs) | [Docs](/DOCS.md) | [Tree-sitter info](#tree-sitter-info) | [Plugins](#plugins) | [Development](#development) | [Kudos](#thanks-to)

</div>

## Installation

Use your favourite package manager:

* [vim-packager](https://github.com/kristijanhusak/vim-packager):

```lua
packager.add('nvim-treesitter/nvim-treesitter')
packager.add('nvim-orgmode/orgmode')
```

- [packer.nvim](https://github.com/wbthomason/packer.nvim)

**Recommended**

```lua
use {'nvim-treesitter/nvim-treesitter'}
use {'nvim-orgmode/orgmode', config = function()
        require('orgmode').setup{}
end
}
```

**Lazy loading (Not recommended)**

Lazy loading via `ft` option works, but not completely. Global mappings are not set because plugin is not initialized on startup.
Above setup has startup time of somewhere between 1 and 3 ms, so there are no many benefits in lazy loading.
If you want to do it anyway, here's the lazy load setup:
```lua
use {'nvim-treesitter/nvim-treesitter'}
use {'nvim-orgmode/orgmode',
    ft = {'org'},
    config = function()
            require('orgmode').setup{}
    end
    }
```

- [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'nvim-orgmode/orgmode'
```

- [dein](https://github.com/Shougo/dein.vim)

```vim
call dein#add('nvim-treesitter/nvim-treesitter')
call dein#add('nvim-orgmode/orgmode')
```

## Setup

```lua
-- init.lua

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
```

Or if you are using `init.vim`:
```vim
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
```

* **Open agenda prompt**: <kbd>\<Leader\>oa</kbd>
* **Open capture prompt**: <kbd>\<Leader\>oc</kbd>
* In any orgmode buffer press <kbd>g?</kbd> for help

If you are new to Orgmode, see [Getting started](/DOCS.md#getting-started-with-orgmode) section in Docs.

### Completion
If you use [nvim-compe](https://github.com/hrsh7th/nvim-compe) and want
to enable autocompletion, add this to your compe config:

```lua
require'compe'.setup({
  source = {
    orgmode = true
  }
})
```

For [nvim-cmp](https://github.com/hrsh7th/nvim-cmp), add `orgmode` to list of sources:
```lua
require'cmp'.setup({
  sources = {
    { name = 'orgmode' }
  }
})
```

For [completion.nvim](https://github.com/nvim-lua/completion-nvim), just add `omni` mode to chain complete list and add additional keyword chars:
```lua
vim.g.completion_chain_complete_list = {
  org = {
    { mode = 'omni'},
  },
}
vim.cmd[[autocmd FileType org setlocal iskeyword+=:,#,+]]
```

Or just use `omnifunc` via <kbd>\<C-x\>\<C-o\></kbd>

### Gifs
#### Agenda
  ![agenda](https://user-images.githubusercontent.com/1782860/123549968-8521f600-d76b-11eb-9a93-02bad08b37ce.gif)

#### Org file
  ![orgfile](https://user-images.githubusercontent.com/1782860/123549982-90752180-d76b-11eb-8828-9edf9f76af08.gif)

#### Capturing and refiling
  ![capture](https://user-images.githubusercontent.com/1782860/123549993-9a972000-d76b-11eb-814b-b348a93df08a.gif)

#### Autocompletion
  ![autocomplete](https://user-images.githubusercontent.com/1782860/123550227-e8605800-d76c-11eb-96f6-c0a677d562d4.gif)

### Tree-sitter info
Built in tree-sitter parser is used for parsing the org files.
Highlights are experimental and partially supported.

#### Advantages of tree-sitter over built in parsing/syntax:
* More reliable, since parsing is done with proper parsing tool
* Better highlighting (Experimental, still requires improvements)
* Future features will be easier to implement because grammar already parses some things that were not parsed before (tables, latex, etc.)
* Allows for easier hacking (custom motions that can work with TS nodes, etc.)

#### Known highlighting issues and limitations
* Performance issues. This is generally an issue in Neovim that should be resolved before 0.6 release (https://github.com/neovim/neovim/issues/14762, https://github.com/neovim/neovim/issues/14762)
* Anything that requires concealing ([org_hide_emphasis_markers](/DOCS.md#org_hide_emphasis_markers), links concealing) is not (yet) supported in TS highlighter
* LaTex is still highlighted through syntax file

#### Improvements over Vim's syntax highlighting
* Better highlighting of certain parts (tags, deadline/schedule/closed dates)
* [Tree-sitter highlight injections](https://github.com/nvim-treesitter/nvim-treesitter/blob/4f2265632becabcd2c5b1791fa31ef278f1e496c/CONTRIBUTING.md#injections) through `#BEGIN_SRC filetype` blocks
* Headline markup highlighting (https://github.com/nvim-orgmode/orgmode/issues/67)

#### Troubleshoot
##### Folding is not working
Make sure you are not overriding foldexpr in Org buffers with [nvim-treesitter folding](https://github.com/nvim-treesitter/nvim-treesitter#folding)

##### Indentation is not working
Make sure you are not overriding indentexpr in Org buffers with [nvim-treesitter indentation](https://github.com/nvim-treesitter/nvim-treesitter#indentation)

##### I get `treesitter/query.lua` errors when opening agenda/capture prompt or org files
Make sure you are using latest changes from [tree-sitter-org](https://github.com/milisims/tree-sitter-org) grammar.<br />
by running `:TSUpdate org` and restarting the editor.

##### Dates are not in English
Dates are generated with Lua native date support, and it reads your current locale when creating them.<br />
To use different locale you can add this to your `init.lua`:
```lua
vim.cmd('language en_US.utf8')
```
or `init.vim`
```
language en_US.utf8
```
Just make sure you have `en_US` locale installed on your system. To see what you have available on the system you can
start the command `:language ` and press `<TAB>` to autocomplete possible options.

##### Links are not concealed
Links are concealed with Vim's conceal feature (see `:help conceal`). To enable concealing, add this to your `init.lua`:
```lua
vim.opt.conceallevel = 2
vim.opt.concealcursor = 'nc'
```

Or if you are using `init.vim`:

```vim
set conceallevel=2
set concealcursor=nc
```

### Features (TL;DR):
* Agenda view
* Search by tags/keyword
* Clocking time
* Repeatable dates, date and time ranges
* Capturing to default notes file/destination
* Archiving (archive file or ARCHIVE tag)
* Exporting (via `emacs`, `pandoc` and custom export options)
* Notifications (experimental, see [Issue #49](https://github.com/nvim-orgmode/orgmode/issues/49))
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
* Repeatable mapping via [vim-repeat](https://github.com/tpope/vim-repeat)

### Features (Detailed breakdown):
* Agenda prompt:
  * Agenda view (<kbd>a</kbd>):
    * Ability to show daily(<kbd>vd</kbd>)/weekly(<kbd>vw</kbd>)/monthly(<kbd>vm</kbd>)/yearly(<kbd>vy</kbd>) agenda
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
    * Navigate forward (<kbd>f</kbd>)/backward(<kbd>b</kbd>) or jump to specific date (<kbd>J</kbd>)
    * Go to task under cursor in current window(<kbd>\<CR\></kbd>) or other window(<kbd>\<TAB\></kbd>)
    * Print category from ":CATEGORY:" property if defined
  * List tasks that have "TODO" state (<kbd>t</kbd>):
  * Find headlines matching tag(s) (<kbd>m</kbd>):
  * Search for headlines (and it's content) for a query (<kbd>s</kbd>):
  * [Advanced search](DOCS.md#advanced-search) for tags/todo kewords/properties
  * Notifications (experimental, see [Issue #49](https://github.com/nvim-orgmode/orgmode/issues/49))
  * Clocking time
* Capture:
  * Define custom templates
  * Fast capturing to default notes file via <kbd>\<C-c\></kbd>
  * Capturing to specific destination <kbd>\<Leader\>or</kbd>
  * Abort capture with <kbd>\<Leader\>ok</kbd>
* Org files
  * Clocking time
  * Refile to destination/headline: <kbd>\<Leader\>or</kbd>
  * Increase/Decrease date under cursor: <kbd>\<C-a\></kbd>/<kbd>\<C-x\></kbd>
  * Change date under cursor via calendar popup: <kbd>cid</kbd>
  * Change headline TODO state: forward<kbd>cit</kbd> or backward<kbd>ciT</kbd>
  * Open hyperlink or date under cursor: <kbd>\<Leader\>oo</kbd>
  * Toggle checkbox: <kbd>\<C-space\></kbd>
  * Toggle current line to headline and vice versa: <kbd>\<Leader\>o*</kbd>
  * Toggle folding of current headline: <kbd>\<TAB\></kbd>
  * Toggle folding in whole file: <kbd>\<S-TAB\></kbd>
  * Archive headline: <kbd>\<Leader\>o$</kbd>
  * Add archive tag: <kbd>\<Leader\>oA</kbd>
  * Change tags: <kbd>\<Leader\>ot</kbd>
  * Promote headline: <kbd><<</kbd>
  * Demote headline: <kbd>>></kbd>
  * Promote subtree: <kbd>\<s</kbd>
  * Demote subtree: <kbd>\>s</kbd>
  * Add headline/list item/checkbox: <kbd>\<Leader\>\<CR\></kbd>
  * Insert heading after current heading and it's content: <kbd>\<Leader\>oih</kbd>
  * Insert TODO heading after current line: <kbd>\<Leader\>oiT</kbd>
  * Insert TODO heading after current heading and it's content: <kbd>\<Leader\>oit</kbd>
  * Move headline up: <kbd>\<Leader\>oK</kb>
  * Move headline down: <kbd>\<Leader\>oJ</kb>
  * Highlighted code blocks (`#+BEGIN_SRC filetype`)
  * Exporting (via `emacs`, `pandoc` and custom export options)

Link to detailed documentation: [DOCS](DOCS.md)

## Plugins
* [org-bullets.nvim](https://github.com/akinsho/org-bullets.nvim) - Show org mode bullets as UTF-8 characters
* [headlines.nvim](https://github.com/lukas-reineke/headlines.nvim) - Add few highlight options for code blocks and headlines
* [sniprun](https://github.com/michaelb/sniprun) - For code evaluation in blocks
* [vim-table-mode](https://github.com/dhruvasagar/vim-table-mode) - For table support

See all available plugins on [orgmode-nvim](https://github.com/topics/orgmode-nvim)

**If you built a plugin please add "orgmode-nvim" topic to it.**

**NOTE**: None of the Emacs Orgmode plugins will be built into orgmode.nvim.
Anything that's a separate plugin in Emacs Orgmode should be a separate plugin in here.
Point of this plugin is to provide functionality that's built into Emacs Orgmode core,
and a good foundation for external plugins.<br />
If you want to build a plugin, post suggestions and improvements on [Plugins infrastructure](https://github.com/nvim-orgmode/orgmode/issues/26)
issue.

## Development

### Tests
 To run tests, [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) is necessary. Once installed, run:
```
make test
```

### Documentation
Vim documentation is auto generated from [DOCS.md](DOCS.md) file with [md2vim](https://github.com/FooSoft/md2vim).

### Formatting
Formatting is done via [StyLua](https://github.com/JohnnyMorganz/StyLua). To format everything run:
```
make format
```

### Parser
Parsing is done via builtin tree-sitter parser and [tree-sitter-org](https://github.com/milisims/tree-sitter-org) grammar.

## Plans
* [X] Support searching by properties
* [ ] Improve checkbox hierarchy
* [X] Support todo keyword faces
* [X] Support clocking work time
* [X] Improve folding
* [X] Support exporting (via existing emacs tools)
* [ ] Support archiving to specific headline
* [ ] Support tables
* [ ] Support diary format dates
* [ ] Support evaluating code blocks

## Thanks to
* [@dhruvasagar](https://github.com/dhruvasagar) and his [vim-dotoo](https://github.com/dhruvasagar/vim-dotoo) plugin
  that got me started using orgmode. Without him this plugin would not happen.
* [@milisims](https://github.com/milisims) for writing a tree-sitter parser for org
* [vim-orgmode](https://github.com/jceb/vim-orgmode) for some parts of the code (mostly syntax)

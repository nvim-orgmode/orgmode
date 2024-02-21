

<div align="center">
  <img alt="A blend of the Neovim (shape) and Org-mode (colours) logos" src="assets/nvim-orgmode.svg" width="250px" />

# nvim-orgmode

  <a href="/LICENSE">![License](https://img.shields.io/badge/license-MIT-brightgreen?style=flat-square)</a><a href="https://ko-fi.com/kristijanhusak"> ![Kofi](https://img.shields.io/badge/support-kofi-00b9fe?style=flat-square&logo=kofi)</a><a href="https://matrix.to/#/#neovim-orgmode:matrix.org"> ![Chat](https://img.shields.io/matrix/neovim-orgmode:matrix.org?logo=matrix&server_fqdn=matrix.org&style=flat-square)</a>


  Orgmode clone written in Lua for Neovim 0.9.2+

  [Setup](#setup) • [Docs](/DOCS.md) • [Showcase](#showcase) • [Treesitter](#treesitter-info) • [Troubleshoot](#troubleshoot) • [Plugins](#plugins) • [Contributing](CONTRIBUTING.md) • [Kudos](#thanks-to)


</div>

## Quickstart

### Requirements

* Neovim 0.9.2 or later
* [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)

### Installation

Use your favourite package manager:

<details open>
  <summary><b><a href="https://github.com/folke/lazy.nvim">lazy.nvim</a> (recommended)</b></summary>
  </br>

```lua
{
  'nvim-orgmode/orgmode',
  dependencies = {
    { 'nvim-treesitter/nvim-treesitter', lazy = true },
  },
  event = 'VeryLazy',
  config = function()
    -- Load treesitter grammar for org
    require('orgmode').setup_ts_grammar()

    -- Setup treesitter
    require('nvim-treesitter.configs').setup({
      highlight = {
        enable = true,
      },
      ensure_installed = { 'org' },
    })

    -- Setup orgmode
    require('orgmode').setup({
      org_agenda_files = '~/orgfiles/**/*',
      org_default_notes_file = '~/orgfiles/refile.org',
    })
  end,
}
```

</details>

<details open>
  <summary><b><a href="https://github.com/wbthomason/packer.nvim">packer.nvim</a></b></summary>
  </br>

```lua
use {'nvim-treesitter/nvim-treesitter'}
use {'nvim-orgmode/orgmode', config = function()
  require('orgmode').setup{}
end
}
```

</details>

<details>
  <summary><a href="https://github.com/junegunn/vim-plug"><b>vim-plug</b></a></summary>
  </br>

```vim
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'nvim-orgmode/orgmode'
```

</details>

<details>
  <summary><a href="https://github.com/Shougo/dein.vim"><b>dein.vim</b></a></summary>
  </br>

```vim
call dein#add('nvim-treesitter/nvim-treesitter')
call dein#add('nvim-orgmode/orgmode')
```

</details>

### Setup

Note that this setup is not needed for [lazy.nvim](https://github.com/folke/lazy.nvim)
since instructions above covers full setup

```lua
-- init.lua

-- Load custom treesitter grammar for org filetype
require('orgmode').setup_ts_grammar()

-- Treesitter configuration
require('nvim-treesitter.configs').setup {
  highlight = {
    enable = true,
  },
  ensure_installed = {'org'}, -- Or run :TSUpdate org
}

require('orgmode').setup({
  org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
})
```

Or if you are using `init.vim`, wrap the above snippet like so:
```vim
" init.vim
lua << EOF

require('orgmode').setup_ts_grammar() ...

EOF
```
#### Completion

<details>
  <summary><a href="https://github.com/hrsh7th/nvim-cmp"><b>nvim-cmp</b></a></summary>
  </br>

```lua
require('cmp').setup({
  sources = {
    { name = 'orgmode' }
  }
})
```

</details>

<details>
  <summary><a href="https://github.com/nvim-lua/completion-nvim"><b>completion-nvim</b></a></summary>
  </br>

```lua
vim.g.completion_chain_complete_list = {
  org = {
    { mode = 'omni'},
  },
}
-- add additional keyword chars
vim.cmd[[autocmd FileType org setlocal iskeyword+=:,#,+]]
```

</details>

Or just use `omnifunc` via <kbd>\<C-x\>\<C-o\></kbd>


### Usage


* **Open agenda prompt**: <kbd>\<Leader\>oa</kbd>
* **Open capture prompt**: <kbd>\<Leader\>oc</kbd>
* In any orgmode buffer press <kbd>g?</kbd> for help

If you are new to Orgmode, see [Getting started](/DOCS.md#getting-started-with-orgmode) section in the Docs
or a hands-on [tutorial](https://github.com/nvim-orgmode/orgmode/wiki/Getting-Started) in our wiki.


## Showcase
### Agenda
  ![agenda](https://user-images.githubusercontent.com/1782860/123549968-8521f600-d76b-11eb-9a93-02bad08b37ce.gif)

### Org file
  ![orgfile](https://user-images.githubusercontent.com/1782860/123549982-90752180-d76b-11eb-8828-9edf9f76af08.gif)

### Capturing and refiling
  ![capture](https://user-images.githubusercontent.com/1782860/123549993-9a972000-d76b-11eb-814b-b348a93df08a.gif)

### Autocompletion
  ![autocomplete](https://user-images.githubusercontent.com/1782860/123550227-e8605800-d76c-11eb-96f6-c0a677d562d4.gif)

## Treesitter Info
The built-in treesitter parser is used for parsing the org files.
Highlights are experimental and partially supported.

### Advantages of treesitter over built in parsing/syntax:
* More reliable, since parsing is done with a proper parsing tool
* Better highlighting (Experimental, still requires improvements)
* Future features will be easier to implement because the grammar already parses some things that were not parsed before (tables, latex, etc.)
* Allows for easier hacking (custom motions that can work with TS nodes, etc.)

### Known highlighting issues and limitations
* LaTex is still highlighted through syntax file

### Improvements over Vim's syntax highlighting
* Better highlighting of certain parts (tags, deadline/schedule/closed dates)
* [Treesitter highlight injections](https://github.com/nvim-treesitter/nvim-treesitter/blob/4f2265632becabcd2c5b1791fa31ef278f1e496c/CONTRIBUTING.md#injections) through `#BEGIN_SRC filetype` blocks
* Headline markup highlighting (https://github.com/nvim-orgmode/orgmode/issues/67)

## Troubleshoot
### Indentation is not working
Make sure you are not overriding indentexpr in Org buffers with [nvim-treesitter indentation](https://github.com/nvim-treesitter/nvim-treesitter#indentation)

### I get `treesitter/query.lua` errors when opening agenda/capture prompt or org files
Make sure you are using latest changes from [tree-sitter-org](https://github.com/milisims/tree-sitter-org) grammar.<br />
by running `:TSUpdate org` and restarting the editor.

### Dates are not in English
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

### Links are not concealed
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

### Jumping to file path is not working for paths with forward slash
If you are using Windows, paths are by default written with backslashes.
To use forward slashes, you must enable `shellslash` option (see `:help 'shellslash'`).

```lua
vim.opt.shellslash = true
```

Or if you are using `init.vim`:

```vim
set shellslash
```

More info on issue [#281](https://github.com/nvim-orgmode/orgmode/issues/281#issuecomment-1120200775)

## Features
### TL;DR
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
* Remote editing from agenda view
* Repeatable mapping via [vim-repeat](https://github.com/tpope/vim-repeat)

### Detailed breakdown
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

**NOTE**: None of the Emacs Orgmode plugins will be built into nvim-orgmode.
Anything that's a separate plugin in Emacs Orgmode should be a separate plugin in here.
The point of this plugin is to provide functionality that's built into Emacs Orgmode core,
and a good foundation for external plugins.<br />
If you want to build a plugin, post suggestions and improvements on [Plugins infrastructure](https://github.com/nvim-orgmode/orgmode/issues/26)
issue.

### :wrench: API

Documentation for our work-in-progress API can be found [here](doc/orgmode_api.txt)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## Documentation

If you are just starting out with orgmode, have a look at the [Getting Started](https://github.com/nvim-orgmode/orgmode/wiki/Getting-Started) section in our wiki.

Vim documentation is auto generated from [DOCS.md](DOCS.md) file with [md2vim](https://github.com/FooSoft/md2vim).

Hosted documentation is on: [https://nvim-orgmode.github.io/](https://nvim-orgmode.github.io/)

## Roadmap
* [X] Support searching by properties
* [ ] Improve checkbox hierarchy
* [X] Support todo keyword faces
* [X] Support clocking work time
* [X] Improve folding
* [X] Support exporting (via existing emacs tools)
* [ ] Support archiving to specific headline
* [X] Support tables
* [ ] Support diary format dates
* [ ] Support evaluating code blocks

## Thanks to
* [@dhruvasagar](https://github.com/dhruvasagar) and his [vim-dotoo](https://github.com/dhruvasagar/vim-dotoo) plugin
  that got me started using orgmode. Without him this plugin would not happen.
* [@milisims](https://github.com/milisims) for writing a treesitter parser for org
* [vim-orgmode](https://github.com/jceb/vim-orgmode) for some parts of the code (mostly syntax)

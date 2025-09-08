<div align="center">
<img alt="A blend of the Neovim (shape) and Org-mode (colours) logos" src="assets/nvim-orgmode.svg" width="250" /><br/>

# nvim-orgmode

<a href="/LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-brightgreen?style=flat-square"></a>
<a href="https://ko-fi.com/kristijanhusak"><img alt="Kofi" src="https://img.shields.io/badge/support-kofi-00b9fe?style=flat-square&logo=kofi"></a>
<a href="https://matrix.to/#/#neovim-orgmode:matrix.org"><img alt="Chat" src="https://img.shields.io/matrix/neovim-orgmode:matrix.org?logo=matrix&server_fqdn=matrix.org&style=flat-square"></a>

Orgmode clone written in Lua for Neovim

[Installation](#installation) • [Docs](#docs) • [Showcase](#showcase) •
[Troubleshoot](./docs/troubleshoot.org) • [Plugins](#plugins) •
[Contributing](./docs/contributing.org) • [Kudos](#thanks-to)

</div>

## Quickstart

### Requirements

- Neovim 0.11.0 or later

### Installation

Use your favourite package manager. We recommend
[lazy.nvim](https://github.com/folke/lazy.nvim):

``` lua
{
  'nvim-orgmode/orgmode',
  event = 'VeryLazy',
  ft = { 'org' },
  config = function()
    -- Setup orgmode
    require('orgmode').setup({
      org_agenda_files = '~/orgfiles/**/*',
      org_default_notes_file = '~/orgfiles/refile.org',
    })

    -- NOTE: If you are using nvim-treesitter with ~ensure_installed = "all"~ option
    -- add ~org~ to ignore_install
    -- require('nvim-treesitter.configs').setup({
    --   ensure_installed = 'all',
    --   ignore_install = { 'org' },
    -- })
  end,
}
```

For more installation options see
[Installation](./docs/installation.org) page.

### Docs

Online docs is available at <https://nvim-orgmode.github.io>.

To view docs in orgmode format in Neovim, run `:Org help`.

Vim help docs is available at `:help orgmode.txt`

### Usage

- **Open agenda prompt**: `<Leader>oa`
- **Open capture prompt**: `<Leader>oc`
- In any orgmode buffer press `g?` for help

If you are new to Orgmode, see [Getting
started](./docs/index.org#getting-started) section in the Docs.

## Showcase

### Agenda

<figure id="agenda">
<img
src="https://user-images.githubusercontent.com/1782860/123549968-8521f600-d76b-11eb-9a93-02bad08b37ce.gif" />
<figcaption>agenda</figcaption>
</figure>

### Org file

<figure id="orgfile">
<img
src="https://user-images.githubusercontent.com/1782860/123549982-90752180-d76b-11eb-8828-9edf9f76af08.gif" />
<figcaption>orgfile</figcaption>
</figure>

### Capturing and refiling

<figure id="capture">
<img
src="https://user-images.githubusercontent.com/1782860/123549993-9a972000-d76b-11eb-814b-b348a93df08a.gif" />
<figcaption>capture</figcaption>
</figure>

### Autocompletion

<figure id="autocomplete">
<img
src="https://user-images.githubusercontent.com/1782860/123550227-e8605800-d76c-11eb-96f6-c0a677d562d4.gif" />
<figcaption>autocomplete</figcaption>
</figure>

## Features

### TL;DR

- Agenda view
- Search by tags/keyword
- Clocking time
- Repeatable dates, date and time ranges
- Capturing to default notes file/destination
- Archiving (archive file or ARCHIVE tag)
- Exporting (via `emacs`, `pandoc` and custom export options)
- Notifications (experimental, see issue
  [\#49](https://github.com/nvim-orgmode/orgmode/issues/49))
- Calendar popup for easier navigation and date updates
- Various org file mappings:
  - Promote/Demote
  - Change TODO state
  - Change dates
  - Insert/Move/Refile headlines
  - Change tags
  - Toggle checkbox state
- Remote editing from agenda view
- Repeatable mapping via
  [vim-repeat](https://github.com/tpope/vim-repeat)

### Detailed breakdown

- Agenda prompt:
  - Agenda view (`a`):
    - Ability to show
      daily(`vd`)/weekly(`vw`)/monthly(`vm`)/yearly(`vy`) agenda
    - Support for various date settings:
      - DEADLINE: Warning settings - example:
        `<2021-06-11 Fri 11:00 -1d>`
      - SCHEDULED: Delay setting - example: `<2021-06-11 Fri 11:00 -2d>`
      - All dates - Repeater settings:
        - Cumulate type: `<2021-06-11 Fri 11:00 +1w>`
        - Catch-up type: `<2021-06-11 Fri 11:00 ++1w>`
        - Restart type: `<2021-06-11 Fri 11:00 .+1w>`
      - Time ranges - example: `<2021-06-11 Fri 11:00-12:30>`
      - Date ranges - example:
        `<2021-06-11 Fri 11:00-12:30>--<2021-06-13 Sun 22:00>`
    - Properly lists tasks according to defined dates
      (DEADLINE,SCHEDULED,Plain date)
    - Navigate forward (`f`)/backward(`b`) or jump to specific date
      (`J`)
    - Go to task under cursor in current window(`<CR>`) or other
      window(`<TAB>`)
    - Print category from ":CATEGORY:" property if defined
  - List tasks that have "TODO" state (`t`):
  - Find headlines matching tag(s) (`m`):
  - Search for headlines (and it's content) for a query (`s`):
  - [Advanced search](./docs/configuration.org#advanced-search) for
    tags/todo kewords/properties
  - Notifications (experimental, see issue
    [\#49](https://github.com/nvim-orgmode/orgmode/issues/49))
  - Clocking time
- Capture:
  - Define custom templates
  - Fast capturing to default notes file via `<C-c>`
  - Capturing to specific destination `<Leader>or`
  - Abort capture with `<Leader>ok`
- Org files
  - Clocking time
  - Refile to destination/headline: `<Leader>or`
  - Increase/Decrease date under cursor: `<C-a>` / `<C-x>`
  - Change date under cursor via calendar popup: `cid`
  - Change headline TODO state: forward `cit` or backward `ciT`
  - Open hyperlink or date under cursor: `<Leader>oo`
  - Toggle checkbox: `<C-space>`
  - Toggle current line to headline and vice versa: `<Leader>o*`
  - Toggle folding of current headline: `<TAB>`
  - Toggle folding in whole file: `<S-TAB>`
  - Archive headline: `<Leader>o$`
  - Add archive tag: `<Leader>oA`
  - Change tags: `<Leader>ot`
  - Promote headline: `<<`
  - Demote headline: `>>`
  - Promote subtree: `<s`
  - Demote subtree: `>s`
  - Add headline/list item/checkbox: `<Leader><CR>`
  - Insert heading after current heading and it's content: `<Leader>oih`
  - Insert TODO heading after current line: `<Leader>oiT`
  - Insert TODO heading after current heading and it's content:
    `<Leader>oit`
  - Move headline up: `<Leader>oK`
  - Move headline down: `<Leader>oJ`
  - Highlighted code blocks (`#+BEGIN_SRC filetype`) Exporting (via
    `emacs`, `pandoc` and custom export options)

Link to detailed documentation: [DOCS](./docs/index.org)

## Plugins

Check [Plugins](./docs/plugins.org) page for list of plugins.

> **NOTE**: None of the Emacs Orgmode plugins will be built into
> nvim-orgmode. Anything that's a separate plugin in Emacs Orgmode
> should be a separate plugin in here. The point of this plugin is to
> provide functionality that's built into Emacs Orgmode core, and a good
> foundation for external plugins.

If you want to build a plugin, post suggestions and improvements on
[Plugins
infrastructure](https://github.com/nvim-orgmode/orgmode/issues/26)
issue.

## Thanks to

- [@dhruvasagar](https://github.com/dhruvasagar) and his
  [vim-dotoo](https://github.com/dhruvasagar/vim-dotoo) plugin that got
  me started using orgmode. Without him this plugin would not happen.
- [@emiasims](https://github.com/emiasims) for writing a treesitter
  parser for org
- [vim-orgmode](https://github.com/jceb/vim-orgmode) for some parts of
  the code (mostly syntax)

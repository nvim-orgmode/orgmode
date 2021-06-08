# Orgmode.nvim

Orgmode clone written in Lua for Neovim 0.5.

## Installation

Use your favourite package manager:

* [vim-packager](https://github.com/kristijanhusak/vim-packager):
  ```lua
    packager.add('kristijanhusak/orgmode.nvim')
  ```
## Setup

```lua
require('orgmode').setup({
  org_agenda_file = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
})
```

## Thanks to
* [@dhruvasagar](https://github.com/dhruvasagar) and his [vim-dotoo](https://github.com/dhruvasagar/vim-dotoo) plugin
  that got me started using orgmode. Without him this plugin would not happen.
* [vim-orgmode](https://github.com/jceb/vim-orgmode) for some parts of the code (mostly syntax)

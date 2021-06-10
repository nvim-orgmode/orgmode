# Table of content

1. [Settings](#settings)
   1. [Global settings](#global-settings)
   2. [Agenda settings](#global-settings)
   3. [Tags settings](#global-settings)
2. [Mappings](#mappings)
   1. [Global Mappings](#global-mappings)
   2. [Agenda Mappings](#agenda-mappings)
   3. [Capture Mappings](#capture-mappings)
   4. [Org Mappings](#org-mappings)

## Settings
Variable names mostly follow the same naming as Orgmode mappings.
Biggest difference is that underscores are being used instead of hyphens.

[Link to all settings file](lua/orgmode/config/defaults.lua)


### Global settings

* `org_agenda_files`\
  type: `string|string[]`\
  default value: `''`\
  Glob path where agenda files are read from. Can provide multiple paths via array.\
  Examples:
    * `'~/Dropbox/org/*'`,
    * `{'~/Dropbox/org/*', '~/my-orgs/**/*'}`

* `org_default_notes_file`\
  type: `string`\
  default value: `''`\
  Path to a file that will be used as a default target file when refiling\
  Example: `~/Dropbox/org/notes.org`

* `org_todo_keywords`,\
  type: `string[]`\
  default value: `{'TODO', '|', 'DONE'}`\
  List of "unfinished" and "finished" states. `|` is used as a separator between "unfinished" and "finished".\
  If `|` is omitted, only last entry in array is considered a "finished" state.\
  Examples:
    * `{'TODO', 'NEXT', '|', 'DONE'}`
    * `{'TODO', 'WAITING', '|', 'DONE', 'DELEGATED'}`

* `org_archive_location`\
  type: `string`\
  default value: `'%s_archive::'`\
  Destination file for archiving. `%s` indicates the current file. `::` is used as a separator for archiving to headline\
  which is currently not supported.\
  This means that if you do a refile from a file `~/my-orgs/todos.org`, your task\
  will be archived in `~/my-orgs/todos.org_archive`.\
  Example values:
    * `'~/my-orgs/default-archive-file.org::'`
  This value can be overridden per file basis with a org special keyword `#+ARCHIVE`.\
    Example: `#+ARCHIVE: ~/path/to/archive_file.org`

## Agenda settings

* `org_deadline_warning_days` = 14,\
  type: `number`,\
  default value: `14`\
  Number of days during which deadline becomes visible in today's agenda.\
  Example:
    If Today is `2021-06-10`, and we have these tasks:\
    `Task 1` has a deadline date `2021-06-15`\
    `Task 2` has a deadline date `2021-06-30`\
    \
    `Task 1` is visible in today's agenda\
    `Task 2` is not visible in today's agenda until `2021-06-16`\

* `org_agenda_span` = 'week',\
  type: `string|number`\
  default value: 'week'\
  possible string values: `day`, `week`, `month`, `year`\
  Default time span shown when agenda is opened.\

* `org_agenda_start_on_weekday` = 1,\
  type: `number`\
  default value: `1`\
  From which day in week (ISO weekday, 1 is Monday) to show the agenda. Applies only to `week` and number span.\
  If set to `nil`, starts from today\

* `org_agenda_start_day` = nil,\
  type: 'string'\
  default value: `nil`\
  example values: `+2d`, `-1d`\
  offset to apply to the agenda start date.\
  Example:\
    If `org_agenda_start_on_weekday` is `nil`, and `org_agenda_start_day` is `-2d`,\
    agenda will always show current week from today - 2 days\

* `org_agenda_templates`,\
  type: `table<string, table>`\
  default value: `{ t = { description: 'Task', template: '* TODO %?\n  %u' } }`\
  Templates for capture/refile prompt.\
  Variables:
    * `%t`: Prints current date (Example: `<2021-06-10 Thu>`) `%T`: Prints current date and time (Example: `<2021-06-10 Thu 12:30>`)
    * `%u`: Prints current date in inactive format (Example: `[2021-06-10 Thu]`)
    * `%U`: Prints current date and time in inactive format (Example: `[2021-06-10 Thu 12:30]`)
    * `%?`: Default cursor position when template is opened

* `org_priority_highest`\
  type: `string|number`\
  default value: `A`\
  Indicates highest priority for a task in the agenda view.\
  Example:\
    `* TODO [#A] This task has the highest priority`

* `org_priority_default`\
  type: `string|number`\
  default value: `B`\
  Indicates normal priority for a task in the agenda view.\
  This is the default priority for all tasks if other priority is not applied\
  Example:\
    `* TODO [#B] This task has the normal priority`\
    `* TODO And this one has the same priority`

* `org_priority_lowest`\
  type: `string|number`\
  default value: `C`\
  Indicates lowest priority for a task in the agenda view.\
  Example:\
    `* TODO [#B] This task has the normal priority`\
    `* TODO And this one has the same priority`\
    `* TODO [#C] I'm lowest in priority`

### Tags settings

* `org_use_tag_inheritance`
  type: `boolean`
  default value: `true`
  When set to `true`, tags are inherited from parents for purposes of searching. Which means that if you have this structure:
  ```
  * TODO My top task :MYTAG:
  ** TODO MY child task :CHILDTAG:
  *** TODO Nested task
  ```
  First headline has tag `MYTAG`
  Second headline has tags `MYTAG` and `CHILDTAG`
  Third headline has tags `MYTAG` and `CHILDTAG`
  When disabled, headlines have only tags that are directly applied to them.

* `org_tags_exclude_from_inheritance`\
  type: `string[]`\
  default value: `{}`\
  List of tags that are excluded from inheritance.\
  Using the example above, setting this variable to `{'MYTAG'}`, second and third headline would have only `CHILDTAG`, where `MYTAG` would not be inherited.\

## Mappings

Mappings try to mimic some of the Orgmode mappings, but since Orgmode uses `CTRL + c` as a modifier most of the time, we have to take a different route.
When possible, instead of `CTRL + C`, prefix `<Leader>o` is used.

To disable all mappings, just pass `disable_all = true` to mappings settings:
```lua
require('orgmode').setup({
  org_agenda_file = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
  mappings = {
    disable_all = true
  }
})
```

**NOTE**: All mappings are normal mode mappings (`nnoremap`)

## Global mappings

There are only 2 global mappings that are accessible from everywhere:

* Open agenda prompt(`org_agenda`): `<Leader>oa`
* Open capture prompt(`org_capture`): `<Leader>oc`

These live under `mappings.global` and can be overridden like this:

```lua
require('orgmode').setup({
  org_agenda_file = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
  mappings = {
    global = {
      org_agenda = 'gA',
      org_capture = 'gC'
    }
  }
})
```

If you want to use multiple mappings for same thing, pass array of mappings:

```lua
require('orgmode').setup({
  org_agenda_file = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
  mappings = {
    global = {
      org_agenda = {'gA', '<Leader>oa'},
      org_capture = {'gC', '<Leader>oc'}
    }
  }
})
```

## Agenda mappings

Mappings used in agenda view window.

* Go to next agenda span(`org_agenda_later`): `f`
* Go to previous agenda span (`org_agenda_earlier`): `b`
* Go to span with for today(`org_agenda_goto_today`): `.`
* Show agenda day view(`org_agenda_day_view `)= `vd`
* Show agenda week view(`org_agenda_week_view`): `vw`
* Show agenda month view(`org_agenda_month_view`): `vm`
* Show agenda year view(`org_agenda_year_view`): `vy`
* Close agenda(`org_agenda_quit`): `q`
* Open selected agenda item in the same buffer(`org_agenda_switch_to`): `<CR>`
* Open selected agenda item in split window(`org_agenda_goto`): `{'<TAB>', '<RightMouse>'}`
* Open calendar that allows selecting date to jump to(`org_agenda_goto_date`): `J`
* Reload all org files and refresh current agenda view(`org_agenda_redo`): `r`

These mappings live under `mappings.agenda`, and can be changed like this:

```lua
require('orgmode').setup({
  org_agenda_file = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
  mappings = {
    agenda = {
      org_agenda_later = '>',
      org_agenda_earlier = '<',
      org_agenda_goto_today = {'.', 'T'}
    }
  }
})
```

## Capture mappings

Mappings used in capture window.

* Save current capture content to `org_default_notes_file` and close capture window(`org_capture_finalize`): `<C-c>`
* Refile capture content to specific destination(`org_capture_refile`): `<Leader>or`
* Close capture window without saving anything(`org_capture_kill`): `<Leader>ok`

These mappings live under `mappings.capture`, and can be changed like this:

```lua require('orgmode').setup({
  org_agenda_file = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
  mappings = {
    capture = {
      org_capture_finalize = '<Leader>w',
      org_capture_refile = 'R',
      org_capture_kill = 'Q'
    }
  }
})
```

## Org mappings

Mappings for `org` files.
* Refile current headline to destinaton(`org_capture_refile`): '<Leader>or'
* Increase date under cursor by 1 day (`org_increase_date`): `<C-a>`
* Decrease date under cursor by 1 day (`org_decrease_date`): `<C-x>`
* Change date under cursor. Opens calendar to select new date(`org_change_date`): `cid`
* Cycle todo keyword forward on current headline (TODO -> DONE -> EMPTY -> TODO, etc.) (`org_todo`): `cit`
* Cycle todo keyword forward on current headline (TODO -> EMPTY -> DONE -> TODO, etc.) (`org_todo_prev`): `ciT`
* Toggle current line checkbox state(`org_toggle_checkbox`): `<C-Space>`
* Cycle folding for current headline(`org_cycle`): `<TAB>`
* Cycle global folding (`org_global_cycle`) = `<S-TAB>`
* Archive current headline to archive location (`org_archive_subtree`): `<Leader>o$`
* Set tags on current headline(`org_set_tags_command`): `<Leader>ot`
* Toggle "ARCHIVE" tag on current headline(`org_toggle_archive_tag`): `<Leader>oA`
* Promote headline(`org_do_promote`): `<<`
* Demote headline(`org_do_demote`): `>>`
* Add headline, list item or checkbox below, depending on current line(`org_meta_return`): `<Leader><CR>`
* Add headline after current headline + it's content with same level (`org_insert_heading_respect_content`): `<Leader>oih`
* Add TODO headline right after the current headline(`org_insert_todo_heading`): `<Leader>oiT`
* Add TODO headliner after current headline + it's content(`org_insert_todo_heading_respect_content`): `<Leader>oit`
* Move current headline + it's content up by one headline(`org_move_subtree_up`): `<Leader>oK`
* Move current headline + it's content down by one headline(`org_move_subtree_down`): `<Leader>oJ`

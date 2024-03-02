# Table of content

1. [Getting started with Orgmode](#getting-started-with-orgmode)
2. [Settings](#settings)
   1. [Global settings](#global-settings)
   2. [Agenda settings](#agenda-settings)
   3. [Tags settings](#tags-settings)
3. [Mappings](#mappings)
   1. [Global mappings](#global-mappings)
   2. [Agenda mappings](#agenda-mappings)
   3. [Capture mappings](#capture-mappings)
   4. [Note mappings](#note-mappings)
   5. [Org mappings](#org-mappings)
   6. [Edit Src mappings](#edit-src)
   7. [Text objects](#text-objects)
   8. [Dot repeat](#dot-repeat)
4. [Tables](#tables)
5. [Hyperlinks](#hyperlinks)
6. [Autocompletion](#autocompletion)
7. [Abbreviations](#abbreviations)
8. [Formatting](#formatting)
9. [User interface](#user-interface)
    1. [Colors](#colors)
    2. [Menu](#menu)
10. [Advanced search](#advanced-search)
11. [Notifications (experimental)](#notifications-experimental)
12. [Clocking](#clocking)
13. [Extract source code (tangle)](#extract-source-code-tangle)
14. [Changelog](#changelog)

## Getting started with Orgmode
To get a basic idea how Orgmode works, look at this screencast from [@dhruvasagar](https://github.com/dhruvasagar)
that demonstrates how the similar Orgmode clone [vim-dotoo](https://github.com/dhruvasagar/vim-dotoo) works.

[https://www.youtube.com/watch?v=nsv33iOnH34](https://www.youtube.com/watch?v=nsv33iOnH34)

## Settings
Variable names mostly follow the same naming as Orgmode mappings.
Biggest difference is that underscores are being used instead of hyphens.

[Link to all settings file](lua/orgmode/config/defaults.lua)

### Global settings

#### **org_agenda_files**
*type*: `string|string[]`<br />
*default value*: `''`<br />
Glob path where agenda files are read from. Can provide multiple paths via array.<br />
Examples:
  * `'~/Dropbox/org/*'`,
  * `{'~/Dropbox/org/*', '~/my-orgs/**/*'}`

#### **org_default_notes_file**
*type*: `string`<br />
*default value*: `''`<br />
Path to a file that will be used as a default target file when refiling<br />
Example: `~/Dropbox/org/notes.org`

#### **org_todo_keywords**
*type*: `string[]`<br />
*default value*: `{'TODO', '|', 'DONE'}`<br />
List of "unfinished" and "finished" states.<br />
`|` is used as a separator between "unfinished" and "finished".<br />
If `|` is omitted, only last entry in array is considered a "finished" state.<br />
To use [Fast access to TODO States](https://orgmode.org/manual/Fast-access-to-TODO-states.html#Fast-access-to-TODO-states)
set a fast access key to at least one of the entries.<br />

Examples (without the fast access):
  * `{'TODO', 'NEXT', '|', 'DONE'}`
  * `{'TODO', 'WAITING', '|', 'DONE', 'DELEGATED'}`

Examples (With fast access):
  * `{'TODO(t)', 'NEXT(n)', '|', 'DONE(d)'}`
  * `{'TODO(t)', 'NEXT', '|', 'DONE'}` - will work same as above. Only one todo keyword needs to have fast access key, others will be parsed from first char.

NOTE: Make sure fast access keys do not overlap. If that happens, first entry in list gets it.

#### **org_todo_repeat_to_state**
*type*: `string|nil`<br />
*default value*: `nil`<br />
Set a [org_todo_keyword](#org-todo-keywords) to use as the "starting" state for repeatable todos.<br />

The keyword set here **must** exist in the [org_todo_keywords](#org-todo-keywords) list, otherwise the first one defined will be used.

#### **win_split_mode**
*type*: `string|function|table`<br />
*default value*: `horizontal`<br />
Available options:
* `horizontal` - Always split horizontally
* `vertical` - Always split vertically
* `auto` - Determine between horizontal and vertical split depending on the current window size
* `float` - Open in float window that has width of 70% of the screen centered
* `{'float', 0.9}` - Open in float window and provide custom scale (in this case it's 90% of screen size), must be value between `0` and `1`

This option determines how to open agenda and capture window.<br />
If none of the options above suit your needs, you can provide custom command string (see `:help <mods>`) or custom function:
Here are few examples:<br />

Open in float window:
```lua
win_split_mode = function(name)
  -- Make sure it's not a scratch buffer by passing false as 2nd argument
  local bufnr = vim.api.nvim_create_buf(false, false)
  --- Setting buffer name is required
  vim.api.nvim_buf_set_name(bufnr, name)

  local fill = 0.8
  local width = math.floor((vim.o.columns * fill))
  local height = math.floor((vim.o.lines * fill))
  local row = math.floor((((vim.o.lines - height) / 2) - 1))
  local col = math.floor(((vim.o.columns - width) / 2))

  vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded"
  })
end
```

Always open in tab:
```
win_split_mode = 'tabnew'
```

Always open vertically:
```
win_split_mode = 'vsplit'
```

Always open horizontally with specific height of 20 lines:
```
win_split_mode = '20split'
```

#### **win_border**
*type*: `string|string[]`<br />
*default value*: `single`<br />
Border style of floating windows.<br />
Available options:
* `none` - No border (default)
* `single` - A single line box
* `double` - A double line box
* `rounded` - Like "single", but with rounded corners ("╭" etc.)
* `solid` - Adds padding by a single whitespace cell
* `shadow` - A drop shadow effect by blending with the background
* `{'╔', '═' ,'╗', '║', '╝', '═', '╚', '║' }` - Specify border characters in a clock-wise fashion
* `{'/', '-', '\\', '|' }` - If less than eight chars the chars will start repeating

See `:help nvim_open_win()`

Applies to:
    always
        - calendar pop-up
        - help pop-up
        - notification pop-up
    `win_split_mode` is set to `float`
        - agenda window
        - capture window

#### **org_startup_folded**
*type*: `string`<br />
*default value*: `overview`<br />
How many headings and other foldable items should be shown when an org file is opened.<br />
Available options:
* `overview` - Only show top level elements (default)
* `content` - Only show the first two levels
* `showeverything` - Show all elements
* `inherit` - Use the fold level set in Neovim's global `foldlevel` option

#### **org_todo_keyword_faces**
*type*: `table<string, string>`<br />
*default value*: `{}`<br />
Custom colors for todo keywords.<br />
Available options:
* foreground - `:foreground hex/colorname`. Examples: `:foreground #FF0000`, `:foreground blue`
* background - `:background hex/colorname`. Examples: `:background #FF0000`, `:background blue`
* weight - `:weight bold`
* underline - `:underline on`
* italic - `:slant italic`

---

Full configuration example with additional todo keywords and their colors:
```lua
require('orgmode').setup({
  org_todo_keywords = {'TODO', 'WAITING', '|', 'DONE', 'DELEGATED'},
  org_todo_keyword_faces = {
    WAITING = ':foreground blue :weight bold',
    DELEGATED = ':background #FFFFFF :slant italic :underline on',
    TODO = ':background #000000 :foreground red', -- overrides builtin color for `TODO` keyword
  }
})
```

#### **org_archive_location**
*type*: `string`<br />
*default value*: `'%s_archive::'`<br />
Destination file for archiving. `%s` indicates the current file. `::` is used as a separator for archiving to headline<br />
which is currently not supported.<br />
This means that if you do a refile from a file `~/my-orgs/todos.org`, your task<br />
will be archived in `~/my-orgs/todos.org_archive`.<br />
Example values:
  * `'~/my-orgs/default-archive-file.org::'`
This value can be overridden per file basis with a org special keyword `#+ARCHIVE`.<br />
  Example: `#+ARCHIVE: ~/path/to/archive_file.org`

#### **org_hide_leading_stars**
*type*: `boolean`<br />
*default value*: `false`<br />
Hide leading stars for headings.<br />
Example:

Disabled (default):
```
* TODO First item
** TODO Second Item
*** TODO Third item
```

Enabled:
```
* TODO First item
 * TODO Second Item
  * TODO Third item
```

**NOTE**: Stars are hidden by applying highlight group that masks them with color that's same as background color.<br />
If this highlight group does not suit you, you can apply different highlight group to it:

```lua
vim.cmd[[autocmd ColorScheme * hi link @org.leading.stars MyCustomHlGroup]]
```

#### **org_hide_emphasis_markers**
*type*: `boolean`<br />
*default value*: `false`<br />
Conceal bold/italic/underline/code/verbatim markers.
Ensure your `:h conceallevel` is set properly in order for this to function.

#### **org_ellipsis**
*type*: `string`<br />
*default value*: `...`<br />
Marker used to indicate a folded headline.
Not applicable with new empty `foldtext` options in Neovim

#### **org_log_done**
*type*: `string|false`<br />
*default value*: `time`<br />
Possible values:
* `time` - adds `CLOSED` date when marking headline as done
* `note` - adds `CLOSED` date as above, and prompts for closing note via capture window. Confirm note with `org_note_finalize` (Default `<C-c>`), or ignore providing note via `org_note_kill` (Default `<Leader>ok`)
* `false` - Disable any logging

#### **org_log_into_drawer**
*type*: `string|nil`<br />
*default value*: `nil`<br />
Possible values:
Log TODO state changes into a drawer with the given name. The recommended value is `LOGBOOK`.
If `nil`, log into the section body.

#### **org_highlight_latex_and_related**
*type*: `string|nil`<br />
*default value*: `nil`<br />
Possible values:
* `native` - Includes whole latex syntax file into the org syntax. It can potentially cause some highlighting issues and slowness.
* `entities` - Highlight latex only in these situations (see [Orgmode latex fragments](https://orgmode.org/manual/LaTeX-fragments.html#LaTeX-fragments)):
  * between `\begin` and `\end` delimiters
  * between `$` and `$` delimiters - example: `$a^2=b$`
  * between `$$` and `$$` delimiters - example: `$$ a=+\sqrt{2} $$`
  * between `\[` and `\]` delimiters - example: `\[ a=-\sqrt{2} \]`
  * between `\(` and `\)` delimiters - example: `\( b=2 \)`

**This option requires setting `additional_vim_regex_highlighting = {'org'}` in tree-sitter configuration since its old Vim syntax**:
```lua
require('nvim-treesitter.configs').setup {
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = {'org'}, -- This line is needed
  },
  ensure_installed = {'org'},
}
```

#### **org_startup_indented**

*type*: `boolean`<br />
*default value*: `false`<br />
Possible values:
* `true` - Uses *Virtual* indents to align content visually. The indents are only visual, they are not saved to the file.
* `false` - Do not add any *Virtual* indentation.

You can toggle Virtual indents on the fly by setting `vim.b.org_indent_mode` to either `true` or `false` when in a org
buffer. For example, if virtual indents were enabled in the current buffer then you could disable them immediately by
setting `vim.b.org_indent_mode = false`.

This feature has no effect when enabled on Neovim versions < 0.10.0

#### **org_adapt_indentation**

*type*: `boolean`<br />
*default value*: `true`<br />
Possible values:
* `true` - Use *hard* indents for content under headlines. Files will save with indents relative to headlines.
* `false` - Do not add any *hard* indents. Files will save without indentation relative to headlines.

#### **org_indent_mode_turns_off_org_adapt_indentation**

*type*: `boolean`<br />
*default value*: `true`<br />
Possible values:
* `true` - Disable [`org_adapt_indentation`](#org_adapt_indentation) by default when [`org_startup_indented`](#org_startup_indented) is enabled.
* `false` - Do not disable [`org_adapt_indentation`](#org_adapt_indentation) by default when [`org_startup_indented`](#org_startup_indented) is enabled.

#### **org_indent_mode_turns_on_hiding_stars**

*type*: `boolean`<br />
*default value*: `true`<br />
Possible values:
* `true` - Enable [`org_hide_leading_stars`](#org_hide_leading_stars) by default when [`org_indent_mode`](#org_startup_indented) is enabled for buffer (`vim.b.org_indent_mode = true`).
* `false` - Do not modify the value in [`org_hide_leading_stars`](#org_hide_leading_stars) by default when [`.org_indent_mode`](#org_startup_indented) is enabled for buffer (`vim.b.org_indent_mode = true`).

#### **org_src_window_setup**
*type*: `string|function`<br />
*default value*: "top 16new"<br />
If the value is a string, it will be run directly as input to `:h vim.cmd`, otherwise if the value is a function it will be called. Both
values have the responsibility of opening a buffer (within a window) to show the special edit buffer. The content of the buffer will be
set automatically, so this option only needs to handle opening an empty buffer.

#### **org_edit_src_content_indentation**
*type*: `number`<br />
*default value*: 0<br />
The indent value for content within `SRC` block types beyond the existing indent of the block itself. Only applied when exiting from
an `org_edit_special` action on a `SRC` block.

#### **org_custom_exports**
*type*: `table`<br />
*default value*: `{}`<br />
Add custom export options to the export prompt. <br />
Structure:
```
  [shortcut:string] = {
    [label:string] = 'Label in export prompt',
    [action:function] = function(exporter)
      return exporter(command:table, target:string, on_success?:function, on_error?:function)
    end
  }
```
Breakdown:
* `shortcut` - single char that will be used to select the export. Make sure it doesn't conflict with existing options
* `action` - function that provides `exporter` function for generating the exports
* `exporter` - function that calls the command provided via `job`
  * `command` - table (array like) that contains command how to generate the export
  * `target` - target file name that will be generated
  * `on_success?` - function that is triggered when export succeeds (command exit status is 0). Provides table parameter with command output. Optional, defaults to prompt to open target file.
  * `on_error?` - function that is triggered when export fails (command exit status is not 0). Provides table parameter with command output. Optional, defaults to printing output as error.

For example, lets add option to export to `rtf` format via `pandoc`:
```lua
require('orgmode').setup({
  org_custom_exports = {
    f = {
      label = 'Export to RTF format',
      action = function(exporter)
        local current_file = vim.api.nvim_buf_get_name(0)
        local target = vim.fn.fnamemodify(current_file, ':p:r')..'.rtf'
        local command = {'pandoc', current_file, '-o', target}
        local on_success = function(output)
          print('Success!')
          vim.api.nvim_echo({{ table.concat(output, '\n') }}, true, {})
        end
        local on_error = function(err)
          print('Error!')
          vim.api.nvim_echo({{ table.concat(err, '\n'), 'ErrorMsg' }}, true, {})
        end
        return exporter(command , target, on_success, on_error)
      end
    }
  }
})
```

#### **org_time_stamp_rounding_minutes**
*type*: `number`<br />
*default value*: `5`<br />
Number of minutes to increase/decrease when using [org_timestamp_up](#org_timestamp_up)/[org_timestamp_down](#org_timestamp_down)

#### **org_blank_before_new_entry**
*type*: `table<string,boolean>`<br />
*default value*: `{ heading = true, plain_list_item = false }`<br />
Determine if blank line should be prepended when:
* Adding heading via `org_meta_return` and `org_insert_*` mappings
* Adding a list item via `org_meta_return`

#### **org_id_uuid_program**
*type*: `string`<br />
*default value*: `uuidgen`<br />
External program used to generate uuid's for id module

#### **org_id_ts_format**
*type*: `string`<br />
*default value*: `%Y%m%d%H%M%S`<br />
Format of the id generated when [org_id_method](#org_id_method) is set to `ts`.

#### **org_id_method**
*type*: `'uuid' | 'ts' | 'org'`<br />
*default value*: `uuid`<br />
What method to use to generate ids via org id module.
* `uuid` - Use [org_id_uuid_program](#org_id_uuid_program) to generate the id
* `ts` - Generate id from current timestamp using format [org_id_ts_format](#org_id_ts_format)
* `org` - Generate a random 12 digit number and prepend [org_id_prefix](#org_id_prefix)

#### **org_id_prefix**
*type*: `string | nil`<br />
*default value*: `nil`<br />
Prefix added to the generated id when [org_id_method](#org_id_method) is set to `org`.

#### **org_id_link_to_org_use_id**
*type*: `boolean`<br />
*default value*: `false`<br />
If `true`, generate ID with the Org ID module and append it to the headline as property. More info on [org_store_link](#org_store_link)

#### **org_babel_default_header_args**
*type*: `table<string, string>`<br />
*default value*: `{ [':tangle'] = 'no', [':noweb']  = no }`<br />
Default header args for extracting source code. See [Extract source code (tangle)](#extract-source-code-tangle) for more details.

#### **calendar_week_start_day**
*type*: `number`<br />
*default value*: `1`<br />
Available options:
* `0` - start week on Sunday
* `1` - start week on Monday

Determine on which day the week will start in calendar modal (ex: [changing the date under cursor](#org_change_date))

#### **emacs_config**
*type*: `table`<br />
*default value*: `{ executable_path = 'emacs', config_path='$HOME/.emacs.d/init.el' }`<br />
Set configuration for your emacs. This is useful for having the emacs export properly pickup your emacs config and plugins.

### Agenda settings

#### **org_deadline_warning_days**
*type*: `number`,<br />
*default value*: `14`<br />
Number of days during which deadline becomes visible in today's agenda.<br />
Example:
  If Today is `2021-06-10`, and we have these tasks:<br />
  `Task 1` has a deadline date `2021-06-15`<br />
  `Task 2` has a deadline date `2021-06-30`<br />
  <br />
  `Task 1` is visible in today's agenda<br />
  `Task 2` is not visible in today's agenda until `2021-06-16`

#### **org_agenda_span**
*type*: `string|number`<br />
*default value*: 'week'<br />
*possible string values*: `day`, `week`, `month`, `year`<br />
Default time span shown when agenda is opened.

#### **org_agenda_start_on_weekday**
*type*: `number`<br />
*default value*: `1`<br />
From which day in week (ISO weekday, 1 is Monday) to show the agenda. Applies only to `week` and number span.<br />
If set to `false`, starts from today

#### **org_agenda_start_day**
*type*: `string`<br />
*default value*: `nil`<br />
*example values*: `+2d`, `-1d`<br />
offset to apply to the agenda start date.<br />
Example:<br />
  If `org_agenda_start_on_weekday` is `false`, and `org_agenda_start_day` is `-2d`,<br />
  agenda will always show current week from today - 2 days

#### **org_capture_templates**
*type*: `table<string, table>`<br />
default value: `{ t = { description = 'Task', template = '* TODO %?\n  %u' } }`<br />
Templates for capture/refile prompt.<br />
Variables:
  * `%f`: Prints the file of the buffer capture was called from
  * `%F`: Like `%f` but inserts the full path
  * `%n`: Inserts the current `$USER`
  * `%t`: Prints current date (Example: `<2021-06-10 Thu>`)
  * `%T`: Prints current date and time (Example: `<2021-06-10 Thu 12:30>`)
  * `%u`: Prints current date in inactive format (Example: `[2021-06-10 Thu]`)
  * `%U`: Prints current date and time in inactive format (Example: `[2021-06-10 Thu 12:30]`)
  * `%a`: File and line number from where capture was initiated (Example: `[[file:/home/user/projects/myfile.txt +2]]`)
  * `%<FORMAT>`: Insert current date/time formatted according to [lua date](https://www.lua.org/pil/22.1.html) format (Example: `%<%Y-%m-%d %A>` produces '2021-07-02 Friday')
  * `%x`: Insert content of the clipboard via the "+" register (see :help clipboard)
  * `%?`: Default cursor position when template is opened
  * `%^{PROMPT|DEFAULT|COMPLETION...}`: Prompt for input, if completion is provided an :h inputlist will be used
  * `%(EXP)`: Runs the given lua code and inserts the result. NOTE: this will internally pass the content to the lua `load()` function. So the body inside `%()` should be the body of a function that returns a string.

Templates have the following fields:
  * `description` (`string`) — description of the template that is displayed in the template selection menu
  * `template` (`string|string[]`) — body of the template that will be used when creating capture
  * `target` (`string?`) — name of the file to which the capture content will be added. If the target is not specified, the content will be added to the [`org_default_notes_file`](#orgdefaultnotesfile) file
  * `headline` (`string?`) — title of the headline after which the capture content will be added. If no headline is specified, the content will be appended to the end of the file
  * `datetree (boolean | { time_prompt?: boolean, reversed?: boolean, tree_type: 'day' | 'month' | 'week' | 'custom' })` — Create a [date tree](https://orgmode.org/manual/Template-elements.html#FOOT84) with current day in the target file and put the capture content there.
    * `true` - Create ascending datetree (newer dates go to end) with the current date
    * `{ time_prompt = true, reversed?: boolean }` - open up a date picker to select a date before opening up a capture buffer
    * `{ reversed: true }` - add entries in reversed order (newer dates comes first)
    * `{ tree_type: 'day' | 'month' | 'week' | 'custom' }` - Which date tree type to use:
      * `day` - Create year -> month -> day structure, and refile headlines in the day headline
      * `month` - Create year -> month structure, and refile headlines in the month headline
      * `week` - Create year -> week number structure, and refile headlines in the week number headline
      * `custom` (**Advanced**) - Create custom datetree with own date formats. This requires adding `tree` property in the `datetree` opts. Example with year and month tree:
        ```lua
        datetree = {
          tree_type = 'custom',
          tree = {
            {
              format = '%Y',
              pattern = '^(%d%d%d%d)$',
              order = { 1 }
            },
            {
              format = '%Y-%m',
              pattern = '^(%d%d%d%d)%-(%d%d)$',
              order = { 1, 2 }
            }
          }
        }
        ```
      Check [this line in source](https://github.com/nvim-orgmode/orgmode/blob/master/lua/orgmode/capture/template/datetree.lua#L144) for builtin tree types
      and detailed explanation how to add own tree.
  * `regexp (string)` — Search for specific line in the target file via regex (same as searching through file from command), and append the content after that line.
    For example, if you have line `appendhere` in target file, put this option to `^appendhere$` to add headlines after that line
  * `properties` (`table?`):
    * `empty_lines` (`table|number?`) — if the value is a number, then empty lines are added before and after the content. If the value is a table, then the following fields are expected:
      * `before` (`integer?`) — add empty lines to the beginning of the content
      * `after` (`integer?`) — add empty lines to the end of the content

Example:<br />
  ```lua
  { T = {
    description = 'Todo',
    template = '* TODO %?\n %u',
    target = '~/org/todo.org'
  } }
  ```

Journal example:<br />
  ```lua
  {
    j = {
      description = 'Journal',
      template = '\n*** %<%Y-%m-%d> %<%A>\n**** %U\n\n%?',
      target = '~/sync/org/journal.org'
    },
  }
  ```

Journal example with dynamic target, i.e. a separate file per month:<br />
  ```lua
  {
    J = {
      description = 'Journal',
      template = '\n*** %<%Y-%m-%d> %<%A>\n**** %U\n\n%?',
      target = '~/sync/org/journal/%<%Y-%m>.org'
    },
  }
  ```

Nested key example:<br />
  ```lua
  {
    e =  'Event',
    er = {
      description = 'recurring',
      template = '** %?\n %T',
      target = '~/org/calendar.org',
      headline = 'recurring'
    },
    eo = {
      description = 'one-time',
      template = '** %?\n %T',
      target = '~/org/calendar.org',
      headline = 'one-time'
    }
  }
  -- or
  {
    e = {
      description = 'Event',
      subtemplates = {
        r = {
          description = 'recurring',
          template = '** %?\n %T',
          target = '~/org/calendar.org',
          headline = 'recurring'
        },
        o = {
          description = 'one-time',
          template = '** %?\n %T',
          target = '~/org/calendar.org',
          headline = 'one-time'
        },
      },
    },
  }
  ```

Lua expression example:<br />
  ```lua
  {
    j = {
      description = 'Journal',
      template = '* %(return vim.fn.getreg "w")',
      -- get the content of register "w"
      target = '~/sync/org/journal.org'
    },
  }
  ```

#### **org_agenda_min_height**
*type*: `number`<br />
*default value*: `16`<br />
Indicates the minimum height that the agenda window will occupy.<br />

#### **org_priority_highest**
*type*: `string|number`<br />
*default value*: `A`<br />
Indicates highest priority for a task in the agenda view.<br />
Example:<br />
  `* TODO [#A] This task has the highest priority`

#### **org_priority_default**
*type*: `string|number`<br />
*default value*: `B`<br />
Indicates normal priority for a task in the agenda view.<br />
This is the default priority for all tasks if other priority is not applied<br />
Example:<br />
  `* TODO [#B] This task has the normal priority`<br />
  `* TODO And this one has the same priority`

#### **org_priority_lowest**
*type*: `string|number`<br />
*default value*: `C`<br />
Indicates lowest priority for a task in the agenda view.<br />
Example:<br />
  `* TODO [#B] This task has the normal priority`<br />
  `* TODO And this one has the same priority`<br />
  `* TODO [#C] I'm lowest in priority`


#### **org_agenda_skip_scheduled_if_done**
*type*: `boolean`<br />
*default value*: `false`<br />

Hide scheduled entries from agenda if they are in a "DONE" state.

#### **org_agenda_skip_deadline_if_done**
*type*: `boolean`<br />
*default value*: `false`<br />

Hide deadline entries from agenda if they are in a "DONE" state.

#### **org_agenda_text_search_extra_files**
*type*: `string[]`<br />
*default value*: `{}`<br />
Additional files to search from agenda search prompt.<br />
Currently it accepts only a single value: `agenda-archives`.<br />
Example value: `{'agenda-archives'}`

### Tags settings

#### **org_tags_column**
*type*: `number`<br />
*default value*: `80`<br />
The column to which tags should be indented in a headline.
If this number is positive, it specifies the column.
If it is negative, it means that the tags should be flushright to that column.
For example, -80 works well for a normal 80 character screen.
When 0, place tags directly after headline text, with only one space in between.

#### **org_use_tag_inheritance**
*type*: `boolean`
*default value*: `true`
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

#### **org_tags_exclude_from_inheritance**
*type*: `string[]`<br />
*default value*: `{}`<br />
List of tags that are excluded from inheritance.<br />
Using the example above, setting this variable to `{'MYTAG'}`, second and third headline would have only `CHILDTAG`, where `MYTAG` would not be inherited.<br />

## Mappings

Mappings try to mimic some of the Orgmode mappings, but since Orgmode uses `CTRL + c` as a modifier most of the time, we have to take a different route.
When possible, instead of `CTRL + C`, prefix `<Leader>o` is used. This is customizable via the `mappings.prefix` setting.

To disable all mappings, just pass `disable_all = true` to mappings settings:
```lua
require('orgmode').setup({
  org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
  mappings = {
    disable_all = true
  }
})
```

To disable a specific mapping, set it's value to `false`:

```lua
require('orgmode').setup({
  org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
  mappings = {
    global = {
      org_agenda = false,
      org_capture = 'gC'
    },
    agenda = {
      org_agenda_later = false
    }
  }
})
```

You can find the configuration file that holds all default mappings [here](./lua/orgmode/config/mappings/init.lua)

**NOTE**: All mappings are normal mode mappings (`nnoremap`) with exception of `org_return`

### Use Enter in insert mode to add list items/checkboxes/todos
By default, adding list items/checkboxes/todos is done with [org_meta_return](#org_meta_return) which is a normal mode mapping.
If you want to have an insert mode mapping there are two options:

1. If your terminal supports it, map a key like `Shift + Enter` to the meta return mapping (Recommended):
```lua
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'org',
  callback = function()
    vim.keymap.set('i', '<S-CR>', '<cmd>lua require("orgmode").action("org_mappings.meta_return")<CR>', {
      silent = true,
      buffer = true,
    })
  end,
})
```
2. If you want to use only enter, enable `org_return_uses_meta_return` option:
```lua
require('orgmode').setup({
  org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
  mappings = {
    org_return_uses_meta_return = true
  }
})
```
This will trigger `org_meta_return` if there is no content after the cursor position (either at the end of line or has just trailing spaces).
Just note that this option always tries to use `meta_return`, which also adds new headlines
automatically if you are on the headline line, which can give undesired results.

### Global mappings

There are only 2 global mappings that are accessible from everywhere.

#### **org_agenda**
*mapped to*:  `<Leader\>oa`<br />
Opens up agenda prompt.

#### **org_capture**
*mapped to*:  `<Leader>oc`<br />
Opens up capture prompt.

These live under `mappings.global` and can be overridden like this:

```lua
require('orgmode').setup({
  org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
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
  org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
  mappings = {
    global = {
      org_agenda = {'gA', '<Leader>oa'},
      org_capture = {'gC', '<Leader>oc'}
    }
  }
})
```

### Agenda mappings

Mappings used in agenda view window.

#### **org_agenda_later**
*mapped to*: `f`<br />
Go to next agenda span
#### **org_agenda_earlier**
*mapped to*: `b`<br />
Go to previous agenda span
#### **org_agenda_goto_today**
*mapped to*: `.`<br />
Go to span with for today
#### **org_agenda_day_view**
*mapped to*: `vd`<br />
Show agenda day view
#### **org_agenda_week_view**
*mapped to*: `vw`<br />
Show agenda week view
#### **org_agenda_month_view**
*mapped to*: `vm`<br />
Show agenda month view
#### **org_agenda_year_view**
*mapped to*: `vy`<br />
Show agenda year view
#### **org_agenda_quit**
*mapped to*: `q`<br />
Close agenda
#### **org_agenda_switch_to**
*mapped to*: `<CR>`<br />
Open selected agenda item in the same buffer
#### **org_agenda_goto**
*mapped to*: `{'<TAB>'}`<br />
Open selected agenda item in split window
#### **org_agenda_goto_date**
*mapped to*: `J`<br />
Open calendar that allows selecting date to jump to
#### **org_agenda_redo**
*mapped to*: `r`<br />
Reload all org files and refresh current agenda view
#### **org_agenda_todo**
*mapped to*: `t`<br />
Change `TODO` state of an item in both agenda and original Org file
#### **org_agenda_clock_in**
*mapped to*: `I`<br />
Clock in item under cursor.<br />
See [Clocking](#clocking) for more details.
#### **org_agenda_clock_out**
*mapped to*: `O`<br />
Clock out currently active clock item.<br />
See [Clocking](#clocking) for more details.
#### **org_agenda_clock_cancel**
*mapped to*: `X`<br />
Cancel clock on currently active clock item.<br />
See [Clocking](#clocking) for more details.
#### **org_agenda_clock_goto**
*mapped to*: `<Leader>oxj`<br />
Jump to currently clocked in headline.<br />
See [Clocking](#clocking) for more details.
#### **org_agenda_clockreport_mode**
*mapped to*: `R`<br />
Show clock report at the end of the agenda for current agenda time range<br />
See [Clocking](#clocking) for more details.
#### **org_agenda_priority**
*mapped to*: `<Leader>o,`<br />
Choose the priority of a headline item.
#### **org_agenda_priority_up**
*mapped to*: `+`<br />
Increase the priority of a headline item.
#### **org_agenda_priority_down**
*mapped to*: `-`<br />
Decrease the priority of a headline item.
#### **org_agenda_archive**
mapped to: `<Leader>o$`<br />
Archive headline item to archive location.
#### **org_agenda_toggle_archive_tag**
*mapped to*: `<Leader>oA`<br />
Toggle "ARCHIVE" tag of a headline item.
#### **org_agenda_set_tags**
*mapped to*: `<Leader>ot`<br />
Set tags on current headline item.
#### **org_agenda_deadline**
*mapped to*: `<Leader>oid`<br />
Insert/Update deadline date on current headline item.<br />
#### **org_agenda_schedule**
*mapped to*: `<Leader>ois`<br />
Insert/Update scheduled date on current headline item.<br />
#### **org_agenda_refile**
*mapped to*: `<Leader>or`<br />
Refile current headline to a destination org-file.
Same as [org_refile](#org_refile) but from agenda view.
#### **org_agenda_filter**
*mapped to*: `/`<br />
Open prompt that allows filtering current agenda view by category, tags and title (vim regex, see `:help vim.regex()`)<br />
Example:<br />
Having `todos.org` file with headlines that have tags `mytag` or `myothertag`, and some of them have `check` in content, this search:<br />
`todos+mytag/check/`<br />
Returns all headlines that are in `todos.org` file, that have `mytag` tag, and have `check` in headline title. Note that regex is case sensitive by default.<br />
Use vim regex flag `\c` to make it case insensitive. See `:help vim.regex()` and `:help /magic`.<br />
Pressing `<TAB>` in filter prompt autocompletes categories and tags.

#### **org_agenda_show_help**
*mapped to*: `g?`<br />
Show help popup with mappings

These mappings live under `mappings.agenda`, and can be changed like this:

```lua
require('orgmode').setup({
  org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
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

### Capture mappings

Mappings used in capture window.

#### **org_capture_finalize**
*mapped to*: `<C-c>`<br />
Save current capture content to `org_default_notes_file` and close capture window
#### **org_capture_refile**
*mapped to*: `<Leader>or`<br />
Refile capture content to specific destination
#### **org_capture_kill**
*mapped to*: `<Leader>ok`<br />
Close capture window without saving anything
#### **org_capture_show_help**
*mapped to*: `g?`<br />
Show help popup with mappings

These mappings live under `mappings.capture`, and can be changed like this:

```lua
require('orgmode').setup({
  org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
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

### Note mappings

Mappings used in closing note window.

#### **org_note_finalize**
*mapped to*: `<C-c>`<br />
Save note window content as closing note for a headline. Ignores first comment (if exists)
#### **org_note_kill**
*mapped to*: `<Leader>ok`<br />
Close note window without saving anything
#### **org_note_show_help**
*mapped to*: `g?`<br />
Show help popup with mappings

These mappings live under `mappings.note`, and can be changed like this:

```lua
require('orgmode').setup({
  org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
  mappings = {
    note = {
      org_note_finalize = '<Leader>w',
      org_note_kill = 'Q'
    }
  }
})
```

### Org mappings

Mappings for `org` files.
#### **org_refile**
*mapped to*: `<Leader>or`<br />
Refile current headline, including its subtree, to a destination org-file. This file must be one of the files specified for the `org_agenda_files` setting. A target headline in the destination file can be specified with `destination.org/<headline>`. If there are multiple headlines with the same name in the destination file, the first occurence will be used.
#### **org_timestamp_up**
*mapped to*: `<C-a>`<br />
Increase date part under under cursor. Accepts count: (Example: `5<C-a>`)<br />
`|` in examples references cursor position.<br />
* Year - Example date: `<202|1-10-01 Fri 10:30>` becomes `<202|2-10-01 Sat 10:30>`
* Month - Example date: `<2021-1|0-01 Fri 10:30>` becomes `<2022-1|1-01 Mon 10:30>`
* Day - Example date: `<2021-10-0|1 Fri 10:30>` becomes `<2022-10-0|2 Sat 10:30>`. Same thing happens when cursor is on day name.
* Hour - Example date: `<2021-10-01 Fri 1|0:30>` becomes `<2022-10-02 Sat 1|1:30>`.
* Minute - Example date: `<2021-10-01 Fri 10:3|0>` becomes `<2022-10-02 Sat 11:3|5>`. See [org_time_stamp_rounding_minutes](#org_time_stamp_rounding_minutes) for steps configuration.
* Repeater/Delay range (`h->d->w->m->y`) - Example date: `<2021-10-01 Fri 10:30 +1|w>` becomes `<2021-10-01 Fri 10:30 +1|m>`
* Active/Inactive state - (`<` to `[` and vice versa) - Example date: `|<2021-10-01 Fri 10:30>` becomes `|[2021-10-01 Fri 10:30]`
#### **org_timestamp_down**
*mapped to*: `<C-x>`<br />
Decrease date part under under cursor.<br />
Same as [org_timestamp_up](#org_timestamp_up), just opposite direction.
#### **org_timestamp_up_day**
*mapped to*: `<S-UP>`<br />
Increase date under cursor by 1 or "count" day(s) (Example count: `5<S-UP>`).
#### **org_timestamp_down_day**
*mapped to*: `<S-DOWN>`<br />
Decrease date under cursor by 1 or "count" day(s) (Example count: `5<S-UP>`).
#### **org_change_date**
*mapped to*: `cid`<br />
Change date under cursor. Opens calendar to select new date
#### **org_priority**
*mapped to*: `<Leader>o,`<br />
Choose the priority of a headline item.
#### **org_priority_up**
*mapped to*: `ciR`<br />
Increase the priority of a headline item.
#### **org_priority_down**
*mapped to*: `cir`<br />
Decrease the priority of a headline item.
#### **org_todo**
*mapped to*: `cit`<br />
Cycle todo keyword forward on current headline or open fast access to TODO states prompt (see [org_todo_keywords](#org_todo_keywords)) if it's enabled.
#### **org_todo_prev**
*mapped to*: `ciT`<br />
Cycle todo keyword backward on current headline.
#### **org_toggle_checkbox**
*mapped to*: `<C-Space>`<br />
Toggle current line checkbox state
#### **org_toggle_heading**
*mapped to*: `<Leader>o*`<br />
Toggle current line to headline and vice versa. Checkboxes will turn into TODO headlines.
#### **org_insert_link**
*mapped to*: `<Leader>oli`<br />
Insert a hyperlink at cursor position. When the cursor is on a hyperlink, edit that hyperlink.<br />
If there are any links stored with [org_store_link](#org_store_link), pressing `<TAB>` to autocomplete the input
will show list of all stored links to select. Links generated with ID are properly expanded to valid links after selection.
#### **org_store_link**
*mapped to*: `<Leader>ols`<br />
Generate a link to the closest headline. If [org_id_link_to_org_use_id](#org_id_link_to_org_use_id) is `true`,
it appends the `ID` property to the headline, and generates link with that id to be inserted via [org_insert_link](#org_insert_link).
When [org_id_link_to_org_use_id](#org_id_link_to_org_use_id) is `false`, it generates the standard file::*headline link (example: `file:/path/to/my/todos.org::*My headline`)
#### **org_open_at_point**
*mapped to*: `<Leader>oo`<br />
Open hyperlink or date under cursor. When date is under the cursor, open the agenda for that day.<br />
#### **org_edit_special**
*mapped to*: `<Leader>o'`<br />
Open a source block for editing in a temporary buffer of the associated `filetype`.<br />
This is useful for editing text with language servers attached, etc. When the buffer is closed, the text of the underlying source block in the original Org file is updated.
*Note that if the Org file that the source block comes from is edited before the special edit buffer is closed, the edits will not be applied. The special edit buffer contents can be recovered from :messages output*
#### **org_cycle**
*mapped to*: `<TAB>`<br />
Cycle folding for current headline
#### **org_global_cycle**
*mapped to*: `<S-TAB>`<br />
Cycle global folding
#### **org_archive_subtree**
*mapped to*: `<Leader>o$`<br />
Archive current headline to archive location
#### **org_set_tags_command**
*mapped to*: `<Leader>ot`<br />
Set tags on current headline
#### **org_toggle_archive_tag**
*mapped to*: `<Leader>oA`<br />
Toggle "ARCHIVE" tag on current headline
#### **org_do_promote**
*mapped to*: `<<`<br />
Promote headline
#### **org_do_demote**
*mapped to*: `>>`<br />
Demote headline
#### **org_promote_subtree**
*mapped to*: `<s`<br />
Promote subtree
#### **org_demote_subtree**
*mapped to*: `>s`<br />
Demote subtree
#### **org_meta_return**
*mapped to*: `<Leader><CR>`<br />
Add headline, list item or checkbox below, depending on current line
#### **org_insert_heading_respect_content**
*mapped to*: `<Leader>oih`<br />
Add headline after current headline + it's content with same level
#### **org_insert_todo_heading**
*mapped to*: `<Leader>oiT`<br />
Add TODO headline right after the current headline
#### **org_insert_todo_heading_respect_content**
*mapped to*: `<Leader>oit`<br />
Add TODO headliner after current headline + it's content
#### **org_move_subtree_up**
*mapped to*: `<Leader>oK`<br />
Move current headline + it's content up by one headline
#### **org_move_subtree_down**
*mapped to*: `<Leader>oJ`<br />
Move current headline + it's content down by one headline
#### **org_export**
*mapped to*: `<Leader>oe`<br />
Open export options.<br />
**NOTE**: Exports are handled via `emacs` and `pandoc`. This means that `emacs` and/or `pandoc` must be in `$PATH`.<br />
see [org_custom_exports](#org_custom_exports) if you want to add your own export options.
#### **org_next_visible_heading**
*mapped to*: `}`<br />
Go to next heading (any level).<br />
#### **org_previous_visible_heading**
*mapped to*: `{`<br />
Go to previous heading (any level).<br />
#### **org_forward_heading_same_level**
*mapped to*: `]]`<br />
Go to next heading on same level. Doesn't go outside of parent.<br />
#### **org_backward_heading_same_level**
*mapped to*: `[[`<br />
Go to previous heading on same level. Doesn't go outside of parent.<br />
#### **outline_up_heading**
*mapped to*: `g{`<br />
Go to parent heading.<br />
#### **org_deadline**
*mapped to*: `<Leader>oid`<br />
Insert/Update deadline date.<br />
#### **org_schedule**
*mapped to*: `<Leader>ois`<br />
Insert/Update scheduled date.<br />
#### **org_time_stamp**
*mapped to*: `<Leader>oi.`<br />
Insert/Update date under cursor.<br />
#### **org_time_stamp_inactive**
*mapped to*: `<Leader>oi!`<br />
Insert/Update inactive date under cursor.<br />
#### **org_clock_in**
*mapped to*: `<Leader>oxi`<br />
Clock in headline under cursor.<br />
See [Clocking](#clocking) for more details.
#### **org_clock_out**
*mapped to*: `<Leader>oxo`<br />
Clock out headline under cursor.<br />
See [Clocking](#clocking) for more details.
#### **org_clock_cancel**
*mapped to*: `<Leader>oxq`<br />
Cancel currently active clock on current headline.<br />
See [Clocking](#clocking) for more details.
#### **org_clock_goto**
*mapped to*: `<Leader>oxj`<br />
Jump to currently clocked in headline.<br />
See [Clocking](#clocking) for more details.
#### **org_set_effort**
*mapped to*: `<Leader>oxe`<br />
Set effort estimate property on for current headline.<br />
See [Clocking](#clocking) for more details.
#### **org_babel_tangle**
*mapped to*: `<leader>obt`<br />
Tangle current file. See [Extract source code (tangle)](#extract-source-code-tangle) for more details.
#### **org_show_help**
*mapped to*: `g?`<br />
Show help popup with mappings

These mappings live under `mappings.org`, and can be changed like this:

```lua
require('orgmode').setup({
  org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
  mappings = {
    org = {
      org_timestamp_up = '+',
      org_timestamp_down = '-'
    }
  }
})
```

### Edit Src

Mappings applied when editing a `SRC` block content via `org_edit_special`.

#### **org_edit_src_abort**
*mapped to*: `<Leader>ok`<br />
Abort changes made to temporary buffer created from the content of a `SRC` block, see above.<br />

#### **org_edit_src_save**
*mapped to*: `<Leader>ow`<br />
Apply changes from the special buffer to the source Org buffer<br />

#### **org_edit_src_show_help**
*mapped to*: `g?`<br />
Show help within the temporary buffer used to edit the content of a `SRC` block.<br />

### Text objects

Operator mappings for `org` files.<br />
Example: Pressing `vir` select everything from current heading and all child.<br />
`inner` means that it doesn't select the stars, where `around` selects `inner` + `stars`.<br />
See [this issue comment](https://github.com/nvim-orgmode/orgmode/issues/48#issuecomment-884528170) for visual preview.<br />

Note: Some mappings can clash with other plugin mappings, like [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) which also has `ih` operator mapping.

#### **inner_heading**
*mapped to*: `ih`<br />
Select inner heading with content.

#### **around_heading**
*mapped to*: `ah`<br />
Select around heading with content.

#### **inner_subtree**
*mapped to*: `ir`<br />
Select whole inner subtree.

#### **around_subtree**
*mapped to*: `ar`<br />
Select around whole subtree.

#### **inner_heading_from_root**
*mapped to*: `Oh` (big letter `o`)<br />
select everything from first level heading to the current heading.

#### **around_heading_from_root**
*mapped to*: `OH` (big letter `o`)<br />
select around everything from first level heading to the current heading.

#### **inner_subtree_from_root**
*mapped to*: `Or` (big letter `o`)<br />
select everything from first level subtree to the current subtree.

#### **around_subtree_from_root**
*mapped to*: `OR` (big letter `o`)<br />
select around everything from first level subtree to the current subtree.<br />

These mappings live under `mappings.text_objects`, and can be changed like this:

```lua
require('orgmode').setup({
  org_agenda_files = {'~/Dropbox/org/*', '~/my-orgs/**/*'},
  org_default_notes_file = '~/Dropbox/org/refile.org',
  mappings = {
    text_objects = {
      inner_heading = 'ic',
    }
  }
})
```

#### **markup text objects**
Mappings to select inner/outer markup entries. For example, having `This is *bold*`, and if cursor is in middle of `*bold*`, doing `ci*` changes only inner text,
and doing `ca*` changes outer text.
These are supported: `*`, `_`, `/`, `+`, `~`, `=`
These cannot be changed.

### Dot repeat
To make all mappings dot repeatable, install [vim-repeat](https://github.com/tpope/vim-repeat) plugin.

## Tables
Tables can be formatted via built in `formatexpr` (see `:help gq`)

For example, having this content:
```
* TODO My headline
  DEADLINE: <2022-05-22 Sun>

  |Header 1|Header 2
  |-
  | col 1| col 2|
```

And going to line `4` and pressing `gqgq`, it will format it to this:
```
* TODO My headline
  DEADLINE: <2022-05-22 Sun>

  | Header 1 | Header 2 |
  |----------+----------|
  | col 1    | col 2    |
```

## Hyperlinks

The format for links is either `[[LINK]]` or `[[LINK][DESCRIPTION]]`. If a description is provided, the actual link is concealed in favor of the description.

Hyperlink types supported:
* URL (http://, https://)
* File (starts with `file:`. Example: `file:/home/user/.config/nvim/init.lua`) Optionally, target can be specified:
  * Headline - It needs to start with `*` (Example: `file:/home/user/org/file.org::*Specific Headline`)
  * Custom id - It needs to start with `#` (Example: `file:/home/user/org/file.org::#my-custom-id`)
  * Line number - It needs to be a number (Example: `file:/home/user/org/file.org::235`)
* Headline title target within the same file (starts with `*`) (Example: `*Specific headline`)
* Headline with `CUSTOM_ID` property within the same file (starts with `#`) (Example: `#my-custom-id`)
* Fallback: If file path, opens the file, otherwise, tries to find the headline title in the current file.

## Autocompletion
By default, `omnifunc` is provided in `org` files that autocompletes these types:
* Tags
* Todo keywords
* Common drawer properties and values (`:PROPERTIES:`, `:CATEGORY:`, `:END:`, etc.)
* Planning keywords (`DEADLINE`, `SCHEDULED`, `CLOSED`)
* Orgfile special keywords (`#+TITLE`, `#+BEGIN_SRC`, `#+ARCHIVE`, etc.)
* Hyperlinks (`* - headlines`, `# - headlines with CUSTOM_ID property`, `headlines matching title`)

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

Note that autocompletion is context aware, which means that
for example tags autocompletion will kick in only when cursor is at the end of headline.
Example (`|` marks the cursor):
```org
* TODO Some task :|
```
Or todo keywords only at the beginning of the headline:
```org
** |
```

Or hyperlinks after double square bracket:
```org
Some content [[|
```

## Abbreviations
`org` buffers have access to two abbreviations:

* `:today:` - expands to today's date (example: `<2021-06-29 Tue>`)
* `:itoday:` - expands to an inactive version of today's date (example: `[2021-06-29 Tue]`)
* `:now:` - expands to today's date and current time (example: `<2021-06-29 Tue 15:32>`)
* `:inow:` - expands to inactive version of today's date and current time (example: `[2021-06-29 Tue 15:32]`)

## Formatting
Formatting is done via `gq` mapping, which uses `formatexpr` under the hood (see `:help formatexpr` for more info).
For example, to re-format whole document, you can do `gggqG`. `gg` goes to first line in current file, `gq` starts the format motion,
and `G` goes to last line in file to make it format the whole thing. To format a single line, do `gqgq`, or to format selection,
select the lines you want to format and just do `gq`.

Currently, these things are formatted:

* Tags are aligned according to the `org_tags_column` setting
* Tables are formatted (see [Tables](#Tables) for more info)
* Clock entries total time is recalculated (see [Recalculating totals](#recalculating-totals) in [Clocking](#Clocking) section)

## User interface

### Colors
Most of the highlight groups are linked to treesitter highlights where applicable (see `:h treesitter-highlight`).

The following highlight groups are used:

  * `@org.headline.level1`: Headline at level 1 - linked to `Title`
  * `@org.headline.level2`: Headline at level 2 - linked to `Constant`
  * `@org.headline.level3`: Headline at level 3 - linked to `Identifier`
  * `@org.headline.level4`: Headline at level 4 - linked to `Statement`
  * `@org.headline.level5`: Headline at level 5 - linked to `PreProc`
  * `@org.headline.level6`: Headline at level 6 - linked to `Type`
  * `@org.headline.level7`: Headline at level 7 - linked to `Special`
  * `@org.headline.level8`: Headline at level 8 - linked to `String`
  * `@org.priority.highest`: Highest priority marker - linked to `@comment.error`
  * `@org.priority.default`: Default priority marker - Not linked to anything, defaults to normal text
  * `@org.priority.lowest`: Lowest priority marker - Not linked to anything, defaults to normal text
  * `@org.timestamp.active`: An active timestamp - linked to `@keyword`
  * `@org.timestamp.inactive`: An inactive timestamp - linked to `@comment`
  * `@org.keyword.todo`: TODO keywords color - Parsed from `Error` (see note below)
  * `@org.keyword.done`: DONE keywords color - Parsed from `DiffAdd` (see note below)
  * `@org.bullet`: A normal bullet under a header item - linked to `@markup.list`
  * `@org.properties`: Property drawer start/end delimiters - linked to `@property`
  * `@org.drawer`: Drawer start/end delimiters - linked to `@property`
  * `@org.tag`: A tag for a headline item, shown on the righthand side like `:foo:` - linked to `@tag.attribute`
  * `@org.plan`: `SCHEDULED`, `DEADLINE`, `CLOSED`, etc. keywords - linked to `Constant`
  * `@org.comment`: A comment block - linked to `@comment`
  * `@org.latex_env`: LaTeX block - linked to `@markup.environment`
  * `@org.directive`: Blocks starting with `#+` - linked to `@comment`
  * `@org.checkbox`: The default checkbox highlight, including square brackets - linked to `@markup.list.unchecked`
  * `@org.checkbox.halfchecked`: A checkbox status (marker between `[]`) checked with `[-]` - linked to `@markup.list.unchecked`
  * `@org.checkbox.checked`: A checkbox status (marker between `[]`) checked with either `[x]` or `[X]` - linked to `@markup.list.checked`
  * `@org.bold`: **bold** text - linked to `@markup.strong`,
  * `@org.bold.delimiter`: bold text delimiter `*` - linked to `@markup.strong`,
  * `@org.italic`: *italic* text - linked to `@markup.italic`,
  * `@org.italic.delimiter`: italic text delimiter `/` - linked to `@markup.italic`,
  * `@org.strikethrough`: ~strikethrough~ text - linked to `@markup.strikethrough`,
  * `@org.strikethrough.delimiter`: strikethrough text delimiter `+` - linked to `@markup.strikethrough`,
  * `@org.underline`: <u>underline<u/> text - linked to `@markup.underline`,
  * `@org.underline.delimiter`: underline text delimiter `_` - linked to `@markup.underline`,
  * `@org.code`: `code` text - linked to `@markup.raw`,
  * `@org.code.delimiter`: code text delimiter `~` - linked to `@markup.raw`,
  * `@org.verbatim`: `verbatim` text - linked to `@markup.raw`,
  * `@org.verbatim.delimiter`: verbatim text delimiter `=` - linked to `@markup.raw`,
  * `@org.hyperlink`: [link](link) text - linked to `@markup.link.url`,
  * `@org.latex`: Inline latex - linked to `@markup.math`,
  * `@org.table.delimiter` - `|` and `-` delimiters in tables - linked to `@punctuation.special`,
  * `@org.table.heading` - Table headings - linked to `@markup.heading`,
  * `@org.edit_src` - The highlight for the source content in an _Org_ buffer while it is being edited in an edit special buffer - linked to `Visual`,
  * `@org.agenda.deadline`: A item deadline in the agenda view - Parsed from `Error` (see note below)
  * `@org.agenda.scheduled`: A scheduled item in the agenda view - Parsed from `DiffAdd` (see note dbelow)
  * `@org.agenda.scheduled_past`: A item past its scheduled date in the agenda view - Parsed from `WarningMsg` (see note below)
  * `@org.agenda.day`: Highlight for all days in Agenda view - linked to `Statement`
  * `@org.agenda.today`: Highlight for today in Agenda view - linked to `@org.bold`
  * `@org.agenda.weekend`: Highlight for weekend days in Agenda view - linked to `@org.bold`

Note:

Colors used for todo keywords and agenda states (deadline, schedule ok, schedule warning)
are parsed from the current colorscheme from several highlight groups (Error, WarningMsg, DiffAdd, etc.).


#### Overriding colors
All colors can be overridden by either setting new values or linking to another highlight group:
```lua
vim.api.nvim_create_autocmd('ColorScheme', {
  pattern = '*',
  callback = function()
    -- Define own colors
    vim.api.nvim_set_hl(0, '@org.agenda.deadline', { fg = '#FFAAAA' })
    vim.api.nvim_set_hl(0, '@org.agenda.scheduled', { fg = '#AAFFAA' })
    -- Link to another highlight group
    vim.api.nvim_set_hl(0, '@org.agenda.scheduled_past', { link = 'Statement' })
  end
})
```

Or in Vimscript:

```vim
autocmd ColorScheme * call s:setup_org_colors()

function! s:setup_org_colors() abort
  " Define own colors
  hi @org.agenda.deadline guifg=#FFAAAA
  hi @org.agenda.scheduled guifg=#AAFFAA
  " Link to another highlight group
  hi link @org.agenda.scheduled_past Statement
endfunction
```

For adding/changing TODO keyword colors see [org-todo-keyword-faces](#org_todo_keyword_faces)

### Menu

The menu is used when selecting further actions in `agenda`, `capture` and `export`. Here is an example of the menu you see when opening `agenda`:

```
Press key for an agenda command
-------------------------------
a Agenda for current week or day
t List of all TODO entries
m Match a TAGS/PROP/TODO query
M Like m, but only for TODO entries
s Search for keywords
q Quit
```
Users have the option to change the appearance of this menu. To do this, you need to add a handler in the UI configuration section:
```lua
require("orgmode").setup({
  ui = {
    menu = {
      handler = function(data)
        -- your handler here, for example:
        local options = {}
        local options_by_label = {}

        for _, item in ipairs(data.items) do
          -- Only MenuOption has `key`
          -- Also we don't need `Quit` option because we can close the menu with ESC
          if item.key and item.label:lower() ~= "quit" then
            table.insert(options, item.label)
            options_by_label[item.label] = item
          end
        end

        local handler = function(choice)
          if not choice then
            return
          end

          local option = options_by_label[choice]
          if option.action then
            option.action()
          end
        end

        vim.ui.select(options, {
          propmt = data.propmt,
        }, handler)
      end,
    },
  },
})
```
When the menu is called, the handler receives a table `data` with the following fields as input:
* `title` (`string`) — menu title
* `items` (`table`) — array containing `MenuItem` (see below)
* `prompt` (`string`) — prompt text used to prompt a keystroke

Each menu item `MenuItem` is one of two types: `MenuOption` and `MenuSeparator`.

`MenuOption` is a table containing the following fields:
* `label` (`string`) — description of the action
* `key` (`string`) — key that will be processed when the keys are pressed in the menu
* `action` (`function` *optional*) — handler that will be called when the `key` is pressed in the menu.

`MenuSeparator` is a table containing the following fields:
* `icon` (`string` *optional*) — character used as separator. The default character is `-`
* `length` (`number` *optional*) — number of repetitions of the separator character. The default length is 80

In order for the menu to work as expected, the handler must call `action` from `MenuItem`.

## Advanced search
Part of [Advanced search](https://orgmode.org/worg/org-tutorials/advanced-searching.html) functionality
is implemented.

To leverage advanced search, open up agenda prompt (default `<Leader>oa`), and select `m` or `M`(todos only) option.

What is supported:

* Operators: `|`, `&`, `+` and `-` (examples: `COMPUTER+URGENT`, `COMPUTER|URGENT`, `+COMPUTER-URGENT`, `COMPUTER|WORK+EMAIL`)
* Search by property with basic arithmetic operators (`<`, `<=`, `=`, `>`, `>=`, `<>`) (examples: `CATEGORY="mycategory"`, `CUSTOM_ID=my_custom_id`, `AGE<10`, `ITEMS>=5`)
* Search by todo keyword (example: `COMPUTER+URGENT/TODO|NEXT`)

Few examples:

* Search all with tag `COMPUTER` **or** `WORK` and `EMAIL`: `COMPUTER|WORK+EMAIL`. `And` always have precedence over `or`.
  Workaround to use first `or` is to write it like this: `COMPUTER+EMAIL|WORK+EMAIL`
* Search all with keyword `TODO`, tag `URGENT` and property `AGE` bigger than 10: `URGENT+AGE>10/TODO`
* Search all with keyword `DONE` or `DELEGATED`, tag `COMPUTER` and property `AGE` not equal to 10: `COMPUTER+AGE<>10/DONE|DELEGATED`
* Search all without keyword `DONE`, tag `URGENT` but without tag `COMPUTER` and property `CATEGORY` equal to `mywork`: `URGENT-COMPUTER+CATEGORY=mywork/-DONE`

## Notifications (experimental)
There is an experimental support for agenda tasks notifications. Related [issue #49](https://github.com/nvim-orgmode/orgmode/issues/49).

Linux/MacOS has support for notifications via:
* System notification app (notify-send/terminal-notifier) (See below for setup)
* As part of Neovim running instance in floating window

Windows support only notifications in running Neovim instance. Any help on this topic is appreciated.

Default configuration (detailed description below):
```lua
require('orgmode').setup({
  notifications = {
    enabled = false,
    cron_enabled = true,
    repeater_reminder_time = false,
    deadline_warning_reminder_time = false,
    reminder_time = 10,
    deadline_reminder = true,
    scheduled_reminder = true,
    notifier = function(tasks)
      local result = {}
      for _, task in ipairs(tasks) do
        require('orgmode.utils').concat(result, {
          string.format('# %s (%s)', task.category, task.humanized_duration),
          string.format('%s %s %s', string.rep('*', task.level), task.todo, task.title),
          string.format('%s: <%s>', task.type, task.time:to_string())
        })
      end

      if not vim.tbl_isempty(result) then
        require('orgmode.notifications.notification_popup'):new({ content = result })
      end
    end,
    cron_notifier = function(tasks)
      for _, task in ipairs(tasks) do
        local title = string.format('%s (%s)', task.category, task.humanized_duration)
        local subtitle = string.format('%s %s %s', string.rep('*', task.level), task.todo, task.title)
        local date = string.format('%s: %s', task.type, task.time:to_string())

        -- Linux
        if vim.fn.executable('notify-send') == 1 then
          vim.loop.spawn('notify-send', { args = { string.format('%s\n%s\n%s', title, subtitle, date) }})
        end

        -- MacOS
        if vim.fn.executable('terminal-notifier') == 1 then
          vim.loop.spawn('terminal-notifier', { args = { '-title', title, '-subtitle', subtitle, '-message', date }})
        end
      end
    end
  },
})
```

Options description:
* `enabled` (boolean) - Enable notifications inside Neovim. Not needed for cron notifications. Default: `false`
* `cron_enabled` (boolean) - Enable notifications via cron. Requires additional setup, see [Cron](#cron) section. Default: `true`
* `repeater_reminder_time` (boolean|number|number[]) - Number of minutes before the repeater time to send notifications.<br />
  For example, if now is `2021-07-15 15:30`, and there's a todo item with date `<2021-07-01 15:30 +1w>`, notification will be sent if value of this setting is `0`.<br />
  If this configuration has a value of `{1, 5, 10}`, this means that notification will be sent on  `2021-07-15 15:20`,  `2021-07-15 15:25` and `2021-07-15 15:29`.<br />
  Default value: `false`, which is disabled.
* `deadline_warning_reminder_time` (boolean|number|number[]) - Number of minutes before the warning time to send notifications.<br />
  For example, if now is `2021-07-15 12:30`, and there's a todo item with date `<2021-07-15 18:30 -6h>`, notification will be sent.<br />
  If this configuration has a value of `{1, 5, 10}`, this means that notification will be sent on  `2021-07-15 12:20`,  `2021-07-15 12:25` and `2021-07-15 12:29`.<br />
  Default value: `0`, which means that it will send notification only on exact warning time
* `reminder_time` (boolean|number|number[]) - Number of minutes before the time to send notifications.<br />
  For example, if now is `2021-07-15 12:30`, and there's a todo item with date `<2021-07-15 12:40>`, notification will be sent.<br />
  If this configuration has a value of `{1, 5, 10}`, this means that notification will be sent on  `2021-07-15 12:20`,  `2021-07-15 12:25` and `2021-07-15 12:29`.<br />
  This reminder also applies to both repeater and warning time if the time is matching. So with the example above, both `2021-07-15 12:20 +1w` and `2021-07-15 12:20 -3h` will trigger notification.<br /> will trigger notification.<br />
  Default value: `10`, which means that it will send notification 10 minutes before the time.
* `deadline_reminder` (boolean) - Should notifications be sent for DEADLINE dates. Default: `true`
* `scheduled_reminder` (boolean) - Should notifications be sent for SCHEDULED dates. Default: `true`
* `notifier` (function) - function for sending notification inside Neovim. Accepts array of tasks (see below) and shows floating window with notifications.
* `cron_notifier` (function) - function for sending notification via cron. Accepts array of tasks (see below) and triggers external program to send notifications.


**Tasks**<br />

Notifier functions accepts `tasks` parameter which is an array of this type:

```lua
{
  file = string, -- (Path to org file containing this task. Example: /home/myhome/orgfiles/todos.org)
  todo = string, -- (Todo keyword on the task. Example value: TODO)
  title = string, -- (Content of the headline without the todo keyword and tag. Example: Submit papers)
  level = number, -- (Headline level (number of asterisks). Example: 1)
  category = string, -- (file name where this task lives. With example file above, this would be: todos),
  priority = string, -- (priority on the task. Example: A)
  tags = string[], -- (array of tags applied to the headline. Example: {'WORK', 'OFFICE'})
  original_time = Date, -- (Date object (see [Date object](lua/orgmode/objects/date.lua) for details) containing original time of the task (with adjustments and everything))
  time = Date, -- (Date object (see [Date object](lua/orgmode/objects/date.lua) for details) time that matched the reminder configuration (with applied adjustments))
  reminder_type = string, -- (Type of the date that matched reminder settings. Can be one of these: repeater, warning or time),
  minutes = number, -- (Number of minutes before the task)
  humanized_duration = string, -- (Humanized duration until the task. Examples: in 10 min., in 5 hr, in 3 hr and 10 min.)
  type = string, -- (Date type. Can be one of these: DEADLINE or SCHEDULED),
  range = table -- (Start and end line of the headline subtree. Example: { start_line = 2, end_line = 5 })
}
```

### Cron

In order to trigger notifications via cron, job needs to be added to the crontab.<br />
This is currently possible only on Linux and MacOS, since I don't know how would this be done on Windows. Any help on this topic is appreciated. <br />
This works by starting the headless Neovim instance, running one off function inside orgmode, and quitting the Neovim.

First try to see if you can run this command:
```
nvim --headless -c 'lua require("orgmode").cron()'
```

If it exits without errors, you are ready!

Here's maximum simplified **Linux** example (Tested on Manjaro/Arch/Ubuntu), but least optimized:

Run this to open crontab:
```
crontab -e
```

Then add this (Ensure path to `nvim` is correct):
```crontab
* * * * * DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus /usr/local/bin/nvim --headless -c 'lua require("orgmode").cron()'
```

More optimized version would be to create a lua file that has only necessary plugins loaded:
```lua
-- ~/.config/nvim/lua/partials/org_cron.lua

-- If you are using lazy.vim do this:
local treesitter = vim.fn.stdpath('data') .. '/lazy/nvim-treesitter'
local orgmode = vim.fn.stdpath('data') .. '/lazy/orgmode'
vim.opt.runtimepath:append(orgmode)
vim.opt.runtimepath:append(treesitter)
-- If you are using Packer or any other package manager that uses built-in package manager, do this:
vim.cmd('packadd nvim-treesitter')
vim.cmd('packadd orgmode')

-- Run the orgmode cron
require('orgmode').cron({
  org_agenda_files = '~/orgmode/*',
  org_default_notes_file = '~/orgmode/notes.org',
  notifications = {
    reminder_time = {0, 5, 10},
  },
})
```

And update cron job to this:

```crontab
* * * * * DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus /usr/local/bin/nvim -u NONE --noplugin --headless -c 'lua require("partials.org_cron")'
```
This option is most optimized because it doesn't load plugins and your init.vim

For **MacOS**, things should be very similar, but I wasn't able to test it. Any help on this is appreciated.

## Clocking
There is partial suport for [Clocking work time](https://orgmode.org/manual/Clocking-Work-Time.html).<br />
Supported actions:
##### Clock in
Org file mapping: `<leader>oxi`<br />
Agenda view mapping: `I`<br />
Start the clock by adding or updating the `:LOGBOOK:` drawer. Note that this clocks out any currently active clock.<br />
Also, agenda/todo/search view highlights item that is clocked in.
##### Clock out
Org file mapping: `<leader>oxo`<br />
Agenda view mapping: `O`<br />
Clock out the entry and update the `:LOGBOOK:` drawer, and also add a total tracked time.<br />
Note that in agenda view pressing `O` anywhere clocks the currently active entry, while in org file cursor must be in the headline subtree.
##### Clock cancel
Org file mapping: `<leader>oxq`<br />
Agenda view mapping: `X`<br />
Cancel the currently active clock. This just removes the entry added by clock in from `:LOGBOOK:` drawer.<br />
Note that in agenda view pressing `X` anywhere cancels clock on the currently active entry, while in org file cursor must be in the headline subtree.
##### Clock goto
Org file mapping: `<leader>oxj`<br />
Agenda view mapping: `<leader>oxj`<br />
Jump to currently clocked in headline in the current window
##### Set effort
Org file mapping: `<leader>oxe`<br />
Agenda view mapping: `<leader>oxe`<br />
Add/Update an Effort estimate property for the current headline
##### Clock report table
Agenda view mapping: `R`<br />
Show the clocking report for the current agenda time range. Headlines from table can be jumped to via `<TAB>/<CR>` (underlined)<br />
Note that this is visible only in Agenda view, since it's the only view that have a time range. Todo/Search views are not supported.
##### Automatic updates of totals
When updating closed logbook dates that have a total at the right (example: `=> 1:05`), updating any of the dates via
[org_timestamp_up](#org_timestamp_up)/[org_timestamp_down](#org_timestamp_down) automatically recalculates this value.
##### Recalculating totals
Org file mapping: `gq` (Note: This is Vim's built in mapping that calls `formatexpr`, see `:help gq`)<br />
If you changed any of the dates in closed logbook entry, and want to recalculate the total, select the line and press `gq`, or
if you want to do it in normal mode, just do `gqgq`.
##### Statusline function
Function: `v:lua.orgmode.statusline()`<br />
Show the currently clocked in headline (if any), with total clocked time / effort estimate (if set).
```vim
set statusline=%{v:lua.orgmode.statusline()}
```

## Extract source code (tangle)
There is basic support for extracting source code with `tangle` and `noweb` (Orgmode link: [Extracting source code](https://orgmode.org/manual/Extracting-Source-Code.html)).
These options are supported:

1. Setting `header-args` on multiple levels:
   1. Configuration ([org_babel_default_header_args](#org_babel_default_header_args))
   2. File level property (`#+property: header-args :tangle yes`)
   3. Headline level property
      ```org
      * Headline
        :PROPERTIES:
        :header-args: :tangle yes
        :END:
      ```
   4. Block level argument
      ```org
      #+begin_src lua :tangle yes
      print('test')
      #+end_src
      ```
2. Tangling all blocks with these options:
   1. `:tangle no` - Do not tangle
   2. `:tangle yes` - Tangle to same filename as current org file, with different extension (If org file is `~/org/todo.org` and block is `#+block_src lua`, tangles to `/org/todo.lua`)
   3. `:tangle path` - Tangle to given filename. It can be absolute (`:tangle /path/to/file.ext`) or relative to current file (either `:tangle ./file.ext` or `:tangle file.ext`)

3. Basic `:noweb` syntax (See [Noweb Reference Syntax](https://orgmode.org/manual/Noweb-Reference-Syntax.html)):
   1. `:noweb no` - Do not expand any references
   2. `:noweb yes` - Expand references via `#+name` directive on block. See example below.
   3. `:noweb tangle` - Same as `:noweb yes`

Example: Having this file in `~/org/todos.org`
```org
* Headline 1
  Content
  Block below will pick up reference from the 2nd block name

  #+begin_src lua :tangle yes :noweb yes
  <<headline2block>>
  print('Headline 1')
  #+end_src

* Headline 2
  Content
  #+name: headline2block
  #+begin_src lua :tangle yes
  print('Headline 2')
  #+end_src
```

Running [org_babel_tangle](#org_babel_tangle) will create file `~/org/todos.lua` with this content:
```lua
print('Headline 2')
print('Headline 1')

print('Headline 2')
```

To extract blocks to specific file, you can set file level property with default path, and maybe exclude 2nd block to not be repeated:

```org
#+property: header-args :tangle ./my_tangled_file.lua
* Headline 1
  Content
  #+begin_src lua :noweb yes
  <<headline2block>>
  print('Headline 1')
  #+end_src

* Headline 2
  Content
  Here we disable tangling, so only first block will give results with the noweb
  #+name: headline2block
  #+begin_src lua :tangle no
  print('Headline 2')
  #+end_src
```

Running [org_babel_tangle](#org_babel_tangle) will create file `~/org/my_tangled_file.lua` with this content:
```lua
print('Headline 2')
print('Headline 1')
```

## Changelog
To track breaking changes, subscribe to [Notice of breaking changes](https://github.com/nvim-orgmode/orgmode/issues/217) issue where those are announced.

#### 25 February 2024

* Add support for extracting source code [Extract source code (tangle)](#extract-source-code-tangle)

#### 21 January 2024

* Option `org_indent_mode` was deprecated in favor of [org_startup_indented](#org_startup_indented). To remove the
  warning use `org_startup_indented`. This was introduced to support Virtual Indent more in line with Emacs.

#### 24 October 2021
* Help mapping was changed from `?` to `g?` to avoid conflict with built in backward search. See issue [#106](https://github.com/nvim-orgmode/orgmode/issues/106).

#### 10 October 2021
* Mappings `org_increase_date` and `org_decrease_date` are deprecated in favor of [org_timestamp_up](#org_timestamp_up) and [org_timestamp_down](#org_timestamp_down).<br />
  If you have these mappings in your custom configuration, you will get a warning each time Orgmode is loaded. To remove the warning, rename the configuration properties accordingly.<br />
  To return the old functionality where mappings increase only the day, add `org_timestamp_up_day`/`org_timestamp_down_day` to your configuration.


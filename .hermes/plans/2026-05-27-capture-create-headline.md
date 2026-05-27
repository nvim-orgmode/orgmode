# Capture: Pass `headline` function the destination file

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** When `headline` in a capture template is a function, call it with the destination file so it can modify the file (create headings, etc.) before returning the headline title — matching Emacs's `file+function` pattern where the function runs in the target file's buffer context.

**Architecture:** Currently `_get_refile_vars` calls `pcall(template_headline)` with no arguments (line 593). Change that to `pcall(template_headline, opts.destination_file)`. The function can then use `file:update_sync(...)` to create any headings it needs, and return the title string. If the headline still doesn't exist after the function returns, the existing error at line 607 fires (the function chose not to create it). No framework-level auto-create — the user's function owns that decision, matching Emacs.

**Tech Stack:** Lua, Neovim API, OrgFile API (`update_sync`, `find_headline_by_title`, `nvim_buf_set_lines`)

**Documentation reference:** docs/configuration.org says `headline` is `string|fun():string?`. We'll update this to `string|fun(OrgFile):string?` — the function receives the destination OrgFile as its first argument.

---

### Task 1: Pass destination file to `headline` function

**Objective:** Change `_get_refile_vars` so the headline function receives the destination file.

**Files:**
- Modify: `lua/orgmode/capture/init.lua` — line ~593

**Step 1: Understand the current code**

```lua
  if opts.template.headline then
    local template_headline = opts.template.headline
    if type(template_headline) == 'function' then
      local ok, resolved_headline = pcall(template_headline)
```

`pcall(template_headline)` calls the function with zero arguments. The file has been loaded and assigned to `opts.destination_file` by this point (line 589).

**Step 2: Make the single-line change**

```lua
      local ok, resolved_headline = pcall(template_headline, opts.destination_file)
```

This is backward-compatible: existing functions that ignore their arguments still work fine.

**Step 3: Verify**

Read the full method to confirm the rest of the error-handling chain is still correct:
- `resolved_headline` is checked for type `'string'` on line 600
- `find_headline_by_title` on line 605
- Error on line 607 if still nil

---

### Task 2: Update EmmyLua annotation on `headline` field

**Objective:** Update the type annotation so the function signature is documented.

**Files:**
- Modify: `lua/orgmode/capture/template/init.lua` — line ~143
- Modify: `lua/orgmode/capture/templates.lua` — check annotation there too

**Step 1: Find and update the annotation**

In `lua/orgmode/capture/template/init.lua`, line 143:

```lua
-- @field headline? string|fun():string
```

Change to:

```lua
---@field headline? string|fun(OrgFile?):string
```

(The requirement to `require('orgmode.files.file')` is already in scope via the file module's own type resolution, or we can use the string `'OrgFile'`.)

**Step 2: Check `templates.lua` for any duplicate annotation**

Read `lua/orgmode/capture/templates.lua` to see if the annotation is duplicated there.

---

### Task 3: Write tests

**Objective:** Write tests confirming a `headline` function can modify the file before returning.

**Files:**
- Modify: `tests/plenary/capture/capture_spec.lua` — add tests to existing `describe('headline creation')` block

**Step 1: Write test: function creates headline then returns its title**

```lua
  it('headline function can create the headline in the file before returning', function()
    local destination_file = helpers.create_file({'* Existing headline'})
    local capture_file = helpers.create_file({'* baz'})
    local item = capture_file:get_headlines()[1]
    local template = Template:new({
      target = destination_file.filename,
      headline = function(file)
        -- Simulate creating a heading (like Emacs file+function)
        file:update_sync(function(f)
          local line_count = vim.api.nvim_buf_line_count(f:bufnr())
          vim.api.nvim_buf_set_lines(f:bufnr(), line_count, line_count, false, { '* My Heading' })
        end)
        return 'My Heading'
      end,
      template = '** %?',
    })
    local capture_window = CaptureWindow:new({ template = template })
    ---@diagnostic disable-next-line: invisible
    capture_window._bufnr = capture_file:bufnr()

    ---@diagnostic disable-next-line: invisible
    local opts = org.capture:_get_refile_vars(capture_window)
    assert.are.same('My Heading', opts.destination_headline:get_title())

    ---@diagnostic disable-next-line: invisible
    org.capture:_refile_from_capture_buffer({
      destination_file = destination_file,
      source_file = capture_file,
      source_headline = item,
      destination_headline = opts.destination_headline,
      template = template,
      capture_window = capture_window,
    })
    vim.cmd('edit ' .. vim.fn.fnameescape(destination_file.filename))
    assert.are.same({
      '* Existing headline',
      '* My Heading',
      '** baz',
    }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
  end)
```

**Step 2: Write test: existing function that ignores its argument still works**

```lua
  it('existing headline function that ignores its argument still works', function()
    local destination_file = helpers.create_file({'* Static Title'})
    local capture_file = helpers.create_file({'* baz'})
    local item = capture_file:get_headlines()[1]
    local template = Template:new({
      target = destination_file.filename,
      headline = function()
        return 'Static Title'
      end,
      template = '%?',
    })
    local capture_window = CaptureWindow:new({ template = template })
    ---@diagnostic disable-next-line: invisible
    capture_window._bufnr = capture_file:bufnr()

    ---@diagnostic disable-next-line: invisible
    local opts = org.capture:_get_refile_vars(capture_window)
    assert.are.same('Static Title', opts.destination_headline:get_title())
  end)
```

**Step 3: Run tests**

Run: `make test FILE=./tests/plenary/capture/capture_spec.lua`
Expected: Existing tests pass, new tests pass.

---

### Task 4: Run full capture test suite

**Objective:** Verify no regressions.

```bash
make test FILE=./tests/plenary/capture/
```

Expected: All tests pass.

---

### Task 5: Run full CI suite

```bash
make test
```

Expected: All tests pass.

---

### Task 6: Commit

The project follows Conventional Commits (per docs/contributing.org §commits):
- `feat(capture):` for new feature in capture module
- `fix:` for bug fixes
- `chore:` for maintenance

```bash
jj describe -m "feat(capture): pass destination file to headline function

When headline is a function, pass the destination OrgFile as its first
argument so the function can modify the target file (create headings,
etc.) before returning the headline title — matching Emacs's file+function
pattern where user code runs in the target file's buffer context.

Existing functions that ignore their argument continue to work unchanged.
The function signature is now fun(OrgFile):string.

AI-assisted: Hermes Agent"
```

## How the user writes their function

With this change, the user's `headline` function in their capture template can do what their Emacs `capture:goto-or-create-heading` does:

```lua
headline = function(file)
  local ts = os.date('%d-%m-%Y')
  local existing = file:find_headline_by_title(ts)
  if not existing then
    file:update_sync(function(f)
      local bufnr = f:bufnr()
      local lc = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_buf_set_lines(bufnr, lc, lc, false, { '* [%] ' .. ts })
    end)
  end
  return ts
end,
```

This mirrors their Emacs function:

```elisp
(defun capture:goto-or-create-heading (timestamp-fn)
  (let* ((ts  (funcall timestamp-fn))
         (pnt (ignore-errors (org-find-olp (list ts) t))))
    (if pnt (goto-char pnt)
      (goto-char (point-max))
      (org-insert-heading nil nil 1)
      (end-of-line)
      (insert "[%] " ts)
      (goto-char (org-find-olp (list ts) t)))))
```

## Edge Cases

- **Function that modifies file but returns a string that still doesn't match**: the existing error at line 607 fires — the function did something wrong.
- **Function that throws**: `pcall` catches it, error returned, `_get_refile_vars` returns false.
- **Function returning non-string**: type check on line 600 catches it.
- **String headline (not a function)**: unchanged behavior — searches, errors if not found.
- **Backward compatibility**: existing `function() return 'title' end` ignores the `file` argument, works fine.

## Verification

- [x] `file:update_sync` — exists on OrgFile (line 161)
- [x] `file:bufnr()` — exists on OrgFile
- [x] `vim.api.nvim_buf_set_lines` — standard nvim API
- [x] `find_headline_by_title` — exists on OrgFile (line 298)
- [x] `vim.fn.confirm` — not used (no prompt, user's function decides)
- [x] `pcall(template_headline, opts.destination_file)` — `pcall` handles the extra arg
- [x] Backward compatible — functions ignoring their argument work fine
- [x] No dead exports created
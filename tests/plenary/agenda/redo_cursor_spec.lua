local helpers = require('tests.plenary.helpers')
local orgmode = require('orgmode')
local config = require('orgmode.config')

local function block(state)
  return {
    type = 'tags_todo',
    org_agenda_overriding_header = state .. ' block',
    match = ('+TODO="%s"'):format(state),
  }
end

---@return string[]
local function build_lines()
  local lines = { '#+TODO: TODO NEXT | DONE', '' }
  for i = 1, 30 do
    table.insert(lines, ('* TODO item %d'):format(i))
    if i ~= 5 then
      table.insert(lines, '  :PROPERTIES:')
      table.insert(lines, ('  :ID: item-%d'):format(i))
      table.insert(lines, '  :END:')
    end
  end
  for i = 1, 30 do
    table.insert(lines, ('* NEXT next %d'):format(i))
  end
  return lines
end

---@param bufnr number
---@param nr number item number
---@return number | nil line number of "item <nr>" in the agenda buffer
local function find_item(bufnr, nr)
  local pattern = ('item %d%%f[^%%d]'):format(nr)
  for lnum, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if line:find(pattern) then
      return lnum
    end
  end
end

---@return number
local function agenda_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'orgagenda' then
      return win
    end
  end
  error('agenda window not found')
end

---@param win number
local function view_of(win)
  return vim.api.nvim_win_call(win, vim.fn.winsaveview)
end

---@param win number
---@param lnum number
---@param topline number
local function set_view(win, lnum, topline)
  vim.api.nvim_win_call(win, function()
    vim.fn.winrestview({ lnum = lnum, topline = topline })
  end)
end

describe('Agenda redo cursor', function()
  ---@type OrgFile
  local file

  before_each(function()
    vim.o.lines = 24
    vim.o.columns = 120
    file = helpers.create_agenda_file(build_lines(), {
      win_split_mode = 'vertical',
      org_agenda_custom_commands = {
        b = { description = 'backlog', types = { block('TODO'), block('NEXT') } },
      },
    })
    for _, t in ipairs(config.org_agenda_custom_commands.b.types) do
      t.org_agenda_files = { file.filename }
    end
    orgmode.agenda:open_by_key('b'):wait()
    assert.are.same('orgagenda', vim.bo.filetype)
  end)

  after_each(function()
    vim.cmd('silent! %bwipeout!')
  end)

  ---@param title string
  ---@param keyword string
  local function set_todo_in_file(title, keyword)
    file
      :update(function()
        local headline = file:find_headline_by_title(title)
        assert(headline, 'headline not found: ' .. title)
        headline:set_todo(keyword)
      end)
      :wait()
  end

  it('keeps the agenda view when redo is called from another window', function()
    local win = agenda_win()
    local bufnr = vim.api.nvim_win_get_buf(win)
    local target = assert(find_item(bufnr, 8))
    set_view(win, target, target - 2)
    -- the org file window is now current, at a line far beyond the agenda length
    vim.cmd('wincmd p')
    assert.are.same('org', vim.bo.filetype)
    vim.fn.cursor({ vim.api.nvim_buf_line_count(0), 1 })
    local other_win = vim.api.nvim_get_current_win()

    orgmode.agenda:redo('remote_edit', true):wait()

    assert.are.same(other_win, vim.api.nvim_get_current_win())
    local view = view_of(win)
    assert.are.same(target, view.lnum)
    assert.are.same(target - 2, view.topline)
  end)

  it('follows the item into another block and keeps its window row', function()
    local win = agenda_win()
    local bufnr = vim.api.nvim_win_get_buf(win)
    local target = assert(find_item(bufnr, 3))
    set_view(win, target, target - 1)
    local row_before = target - view_of(win).topline

    set_todo_in_file('item 3', 'NEXT')
    orgmode.agenda:redo('remote_edit', true):wait()

    local new_line = assert(find_item(bufnr, 3))
    assert.is_true(new_line > target, 'item should have moved into the NEXT block')
    local view = view_of(win)
    assert.are.same(new_line, view.lnum)
    assert.are.same(row_before, view.lnum - view.topline)
    assert.is_true(view.lnum < view.topline + vim.api.nvim_win_get_height(win))
  end)

  it('finds an item without :ID: by its title', function()
    local win = agenda_win()
    local bufnr = vim.api.nvim_win_get_buf(win)
    local target = assert(find_item(bufnr, 5))
    set_view(win, target, target - 1)

    set_todo_in_file('item 5', 'NEXT')
    orgmode.agenda:redo('remote_edit', true):wait()

    local new_line = assert(find_item(bufnr, 5))
    assert.is_true(new_line > target, 'item should have moved into the NEXT block')
    assert.are.same(new_line, view_of(win).lnum)
  end)

  it('stays on the neighbouring line when the item left the view', function()
    local win = agenda_win()
    local bufnr = vim.api.nvim_win_get_buf(win)
    local target = assert(find_item(bufnr, 7))
    set_view(win, target, target - 3)

    set_todo_in_file('item 7', 'DONE')
    orgmode.agenda:redo('remote_edit', true):wait()

    assert.is_nil(find_item(bufnr, 7))
    local view = view_of(win)
    assert.are.same(target, view.lnum)
    assert.are.same(target - 3, view.topline)
    assert.are.same(target, find_item(bufnr, 8))
  end)
end)

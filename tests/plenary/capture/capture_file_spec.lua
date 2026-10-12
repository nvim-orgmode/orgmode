local Capture = require('orgmode.capture')
local Template = require('orgmode.capture.template')
local config = require('orgmode.config')
local org = require('orgmode')

---@type string[] temp files and directories to delete after each test
local created = {}

---@return string path of a file that does not exist yet
local function new_file_path()
  local dir = vim.fn.resolve(vim.fn.tempname())
  table.insert(created, dir)
  return dir .. '/node.org'
end

---@param hooks? table<string, function>
---@return OrgCapture, table<string, integer> calls per hook
local function new_capture(hooks)
  local calls = { pre = 0, post = 0, cancel = 0 }
  hooks = hooks or {}
  local capture = Capture:new({
    files = org.files,
    on_pre_refile = function(...)
      calls.pre = calls.pre + 1
      if hooks.pre then
        hooks.pre(...)
      end
    end,
    on_post_refile = function(...)
      calls.post = calls.post + 1
      if hooks.post then
        hooks.post(...)
      end
    end,
    on_cancel_refile = function()
      calls.cancel = calls.cancel + 1
    end,
  })
  return capture, calls
end

---@param capture OrgCapture
---@param target string
local function open_capture(capture, target)
  capture:open_template(Template:new({ template = '#+TITLE: Node\n\n%?', target = target, whole_file = true }))
  vim.wait(1000, function()
    return vim.b.org_capture == true
  end)
  assert.is.True(vim.b.org_capture)
  vim.cmd('stopinsert')
end

---@param answer number
---@param fn function
---@return string[] questions asked
local function answering(answer, fn)
  local questions = {}
  local original = vim.fn.confirm
  vim.fn.confirm = function(msg)
    table.insert(questions, msg)
    return answer
  end
  local ok, err = pcall(fn)
  vim.fn.confirm = original
  assert(ok, err)
  return questions
end

describe('New full-file capture', function()
  after_each(function()
    config:extend({ win_split_mode = 'horizontal' })
    vim.cmd('silent! %bwipeout!')
    -- Let the close handlers of wiped captures run before the next test
    vim.wait(100)
    for _, path in ipairs(created) do
      vim.fn.delete(path, 'rf')
    end
    created = {}
  end)

  it('edits the new file and keeps the capture open after :w', function()
    local target = new_file_path()
    local capture = new_capture()
    open_capture(capture, target)
    assert.are.same(target, vim.api.nvim_buf_get_name(0))
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'body' })
    vim.api.nvim_win_set_cursor(0, { 4, 2 })

    vim.cmd('silent write')

    assert.are.same({ '#+TITLE: Node', '', '', 'body' }, vim.fn.readfile(target))
    assert.is.True(vim.b.org_capture)
    assert.are.same(target, vim.api.nvim_buf_get_name(0))
    assert.are.same({ 4, 2 }, vim.api.nvim_win_get_cursor(0))

    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'more' })
    vim.cmd('silent write')

    assert.are.same({ '#+TITLE: Node', '', '', 'body', 'more' }, vim.fn.readfile(target))
  end)

  it('finishes with the finalize mapping and leaves a normal buffer', function()
    local target = new_file_path()
    local previous_win = vim.api.nvim_get_current_win()
    local capture, calls = new_capture()
    open_capture(capture, target)
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'body' })

    capture:refile()

    assert.are.same({ '#+TITLE: Node', '', '', 'body' }, vim.fn.readfile(target))
    assert.are.same({ pre = 1, post = 1, cancel = 0 }, calls)
    assert.are.same(previous_win, vim.api.nvim_get_current_win())
    assert.is.True(vim.api.nvim_buf_is_loaded(bufnr))
    assert.is.Nil(vim.b[bufnr].org_capture)
    assert.is.True(vim.bo[bufnr].buflisted)
    assert.are.same('', vim.bo[bufnr].bufhidden)
    local finalize_maps = vim.tbl_filter(function(map)
      return map.lhs == '<C-C>'
    end, vim.api.nvim_buf_get_keymap(bufnr, 'n'))
    assert.are.same({}, finalize_maps)
  end)

  it('finishes with :wq after an earlier :w', function()
    local target = new_file_path()
    local capture, calls = new_capture()
    open_capture(capture, target)
    vim.cmd('silent write')
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'body' })

    vim.cmd('silent wq')
    vim.wait(200)

    assert.are.same({ '#+TITLE: Node', '', '', 'body' }, vim.fn.readfile(target))
    assert.are.same({ pre = 1, post = 1, cancel = 0 }, calls)
  end)

  it('kill after :w empties the file and keeps it on No, undo restores', function()
    local target = new_file_path()
    local previous_win = vim.api.nvim_get_current_win()
    local capture, calls = new_capture()
    open_capture(capture, target)
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'body' })
    vim.cmd('silent write')

    local questions = answering(1, function()
      capture:kill(true)
    end)

    assert.are.same({ 'Delete file for aborted capture?' }, questions)
    assert.are.same({}, vim.fn.readfile(target))
    assert.are.same({ pre = 1, post = 0, cancel = 1 }, calls)
    assert.are.same(previous_win, vim.api.nvim_get_current_win())
    assert.is.True(vim.api.nvim_buf_is_loaded(bufnr))
    assert.is.True(vim.bo[bufnr].buflisted)
    assert.is.Nil(vim.b[bufnr].org_capture)

    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd('silent undo')
    end)

    assert.are.same({ '#+TITLE: Node', '', '', 'body' }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
  end)

  it('kill after :w deletes file and buffer on Yes', function()
    local target = new_file_path()
    local capture, calls = new_capture()
    open_capture(capture, target)
    local bufnr = vim.api.nvim_get_current_buf()
    vim.cmd('silent write')

    answering(2, function()
      capture:kill(true)
    end)

    assert.are.same(0, vim.fn.filereadable(target))
    assert.is.False(vim.api.nvim_buf_is_valid(bufnr))
    assert.are.same(1, calls.cancel)
  end)

  it(':q! answered Yes writes the file and finishes', function()
    local target = new_file_path()
    local capture, calls = new_capture()
    open_capture(capture, target)
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'body' })

    local questions = answering(1, function()
      vim.cmd('quit!')
      vim.wait(200)
    end)

    assert.are.same({ ('Do you want to refile this to %s?'):format(target) }, questions)
    assert.are.same({ '#+TITLE: Node', '', '', 'body' }, vim.fn.readfile(target))
    assert.are.same({ pre = 1, post = 1, cancel = 0 }, calls)
  end)

  it(':q! answered No keeps what :w wrote and finishes', function()
    local target = new_file_path()
    local capture, calls = new_capture()
    open_capture(capture, target)
    vim.cmd('silent write')
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'unsaved' })

    answering(2, function()
      vim.cmd('quit!')
      vim.wait(200)
    end)

    assert.are.same({ '#+TITLE: Node', '', '' }, vim.fn.readfile(target))
    assert.are.same({ pre = 1, post = 1, cancel = 0 }, calls)
  end)

  it(':q! answered No without :w cancels and leaves no file', function()
    local target = new_file_path()
    local capture, calls = new_capture()
    open_capture(capture, target)

    answering(2, function()
      vim.cmd('quit!')
      vim.wait(200)
    end)

    assert.are.same(0, vim.fn.filereadable(target))
    assert.are.same({ pre = 1, post = 0, cancel = 1 }, calls)
  end)

  it(':q! answered with Escape reopens the file capture unchanged', function()
    local target = new_file_path()
    local capture = new_capture()
    open_capture(capture, target)
    vim.cmd('silent write')
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'unsaved' })

    answering(0, function()
      vim.cmd('quit!')
      vim.wait(1000, function()
        return vim.b.org_capture == true
      end)
    end)

    assert.is.True(vim.b.org_capture)
    assert.are.same(target, vim.api.nvim_buf_get_name(0))
    assert.are.same({ '#+TITLE: Node', '', '', 'unsaved' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.is.True(vim.bo.modified)
    assert.has.error(function()
      vim.cmd('quit')
    end)
  end)

  it('can still write after Escape reopened a written capture in a float', function()
    config:extend({ win_split_mode = 'float' })
    local target = new_file_path()
    local capture = new_capture()
    open_capture(capture, target)
    vim.cmd('silent write')
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'unsaved' })
    answering(0, function()
      vim.cmd('quit!')
      vim.wait(1000, function()
        return vim.b.org_capture == true
      end)
    end)

    vim.cmd('silent write')

    assert.are.same({ '#+TITLE: Node', '', '', 'unsaved' }, vim.fn.readfile(target))
  end)

  it('refuses to refile elsewhere and keeps the capture open', function()
    local target = new_file_path()
    local capture, calls = new_capture()
    open_capture(capture, target)

    capture:refile_to_destination()

    assert.is.True(vim.b.org_capture)
    assert.are.same(target, vim.api.nvim_buf_get_name(0))
    assert.are.same({ pre = 1, post = 0, cancel = 0 }, calls)
  end)

  it('runs on_pre_refile once, at open, on the template content', function()
    local root = vim.fn.resolve(vim.fn.tempname())
    table.insert(created, root)
    local seen_title
    local capture, calls = new_capture({
      pre = function(_, opts)
        seen_title = opts.source_file:get_directive('title')
        opts.template.target = root .. '/' .. opts.template.target
      end,
    })
    open_capture(capture, 'node.org')
    assert.are.same(root .. '/node.org', vim.api.nvim_buf_get_name(0))

    capture:refile()

    assert.are.same('Node', seen_title)
    assert.are.same({ pre = 1, post = 1, cancel = 0 }, calls)
    assert.are.same(1, vim.fn.filereadable(root .. '/node.org'))
  end)

  it('captures into an existing file through a temp buffer', function()
    local target = vim.fn.resolve(vim.fn.tempname() .. '.org')
    table.insert(created, target)
    vim.fn.writefile({ '* existing' }, target)
    local capture, calls = new_capture()
    open_capture(capture, target)
    assert.are_not.same(target, vim.api.nvim_buf_get_name(0))
    vim.cmd('silent write')
    assert.are.same({ '* existing' }, vim.fn.readfile(target))

    capture:refile()

    assert.are.same({ '* existing', '#+TITLE: Node', '', '' }, vim.fn.readfile(target))
    assert.are.same(1, calls.post)
  end)

  it('kill without :w leaves no file and asks nothing', function()
    local target = new_file_path()
    local capture, calls = new_capture()
    open_capture(capture, target)
    local bufnr = vim.api.nvim_get_current_buf()

    local questions = answering(2, function()
      capture:kill(true)
    end)

    assert.are.same({}, questions)
    assert.are.same(0, vim.fn.filereadable(target))
    assert.is.False(vim.api.nvim_buf_is_valid(bufnr))
    assert.are.same(1, calls.cancel)
  end)
end)

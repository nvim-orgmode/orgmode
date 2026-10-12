local Capture = require('orgmode.capture')
local Template = require('orgmode.capture.template')
local org = require('orgmode')

---@type string[] temp files to delete after each test
local created = {}

---@param lines string[]
---@return string
local function create_destination(lines)
  local destination = vim.fn.resolve(vim.fn.tempname() .. '.org')
  table.insert(created, destination)
  vim.fn.writefile(lines, destination)
  return destination
end

---@param hooks? { on_post_refile?: function, on_cancel_refile?: function }
---@return OrgCapture
local function new_capture(hooks)
  hooks = hooks or {}
  return Capture:new({
    files = org.files,
    on_post_refile = hooks.on_post_refile,
    on_cancel_refile = hooks.on_cancel_refile,
  })
end

---@param capture OrgCapture
---@param template_opts table
local function open_capture(capture, template_opts)
  capture:open_template(Template:new(template_opts))
  vim.wait(1000, function()
    return vim.b.org_capture == true
  end)
  assert.is.True(vim.b.org_capture)
end

---Replace vim.fn.confirm for the duration of `fn`, answering with `answer`.
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

local function wait_until_no_capture()
  vim.wait(1000, function()
    return vim.b.org_capture == nil
  end)
end

describe('Capture close prompt', function()
  after_each(function()
    vim.cmd('silent! %bwipeout!')
    -- Let the close handlers of wiped captures run before the next test
    vim.wait(100)
    for _, path in ipairs(created) do
      vim.fn.delete(path)
    end
    created = {}
  end)

  it('refiles on Yes after :q!', function()
    local destination = create_destination({ '* existing' })
    local capture = new_capture()
    open_capture(capture, { template = '* %?', target = destination })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '* captured' })

    local questions = answering(1, function()
      vim.cmd('quit!')
      vim.wait(200)
    end)

    assert.are.same({ ('Do you want to refile this to %s?'):format(destination) }, questions)
    assert.are.same({ '* existing', '* captured' }, vim.fn.readfile(destination))
  end)

  it('discards on No after :q! and reports a cancel', function()
    local destination = create_destination({ '* existing' })
    local cancels = 0
    local capture = new_capture({
      on_cancel_refile = function()
        cancels = cancels + 1
      end,
    })
    open_capture(capture, { template = '* %?', target = destination })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '* captured' })

    answering(2, function()
      vim.cmd('quit!')
      vim.wait(200)
    end)

    assert.are.same({ '* existing' }, vim.fn.readfile(destination))
    assert.are.same(1, cancels)
  end)

  it('reopens the capture unchanged on Escape after :q!', function()
    local destination = create_destination({ '* existing' })
    local capture = new_capture()
    open_capture(capture, { template = '* %?', target = destination })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '* captured', 'body' })
    vim.api.nvim_win_set_cursor(0, { 2, 2 })

    answering(0, function()
      vim.cmd('quit!')
      vim.wait(1000, function()
        return vim.b.org_capture == true
      end)
    end)

    assert.is.True(vim.b.org_capture)
    assert.are.same({ '* captured', 'body' }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    assert.are.same({ 2, 2 }, vim.api.nvim_win_get_cursor(0))
    assert.is.True(vim.bo.modified)
    assert.are.same({ '* existing' }, vim.fn.readfile(destination))
    assert.has.error(function()
      vim.cmd('quit')
    end)
  end)

  it('refuses :q with unwritten changes and keeps the capture open', function()
    local destination = create_destination({ '* existing' })
    local capture = new_capture()
    open_capture(capture, { template = '* %?', target = destination })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '* captured' })

    local ok, err = pcall(vim.cmd, 'quit')

    assert.is.False(ok)
    assert.is.Truthy(tostring(err):match('E37'))
    assert.is.True(vim.b.org_capture)
    assert.are.same({ '* existing' }, vim.fn.readfile(destination))
  end)

  it('treats Escape like Yes when Neovim exits', function()
    local destination = create_destination({ '* existing' })
    local capture = new_capture()
    open_capture(capture, { template = '* %?', target = destination })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '* captured' })

    answering(0, function()
      vim.api.nvim_exec_autocmds('VimLeavePre', {})
      vim.wait(200)
    end)

    assert.are.same({ '* existing', '* captured' }, vim.fn.readfile(destination))
  end)

  it('refiles once on Yes after a capture reopened by Escape', function()
    local destination = create_destination({ '* existing' })
    local refiles = 0
    local capture = new_capture({
      on_post_refile = function()
        refiles = refiles + 1
      end,
    })
    open_capture(capture, { template = '* %?', target = destination })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '* captured' })
    answering(0, function()
      vim.cmd('quit!')
      vim.wait(1000, function()
        return vim.b.org_capture == true
      end)
    end)

    answering(1, function()
      vim.cmd('quit!')
      wait_until_no_capture()
      vim.wait(200)
    end)

    assert.are.same({ '* existing', '* captured' }, vim.fn.readfile(destination))
    assert.are.same(1, refiles)
  end)

  it('refiles without asking on :q when nothing is unsaved', function()
    local destination = create_destination({ '* existing' })
    local capture = new_capture()
    open_capture(capture, { template = '* %?', target = destination })
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { '* captured' })
    vim.cmd('silent write')

    local questions = answering(1, function()
      vim.cmd('quit')
      vim.wait(200)
    end)

    assert.are.same({}, questions)
    assert.are.same({ '* existing', '* captured' }, vim.fn.readfile(destination))
  end)
end)
